//
//  RenderResViewController.swift
//  RTIScan
//
//  Created by yang yuan on 3/9/19.
//  Copyright © 2019 Yuan Yang. All rights reserved.
//

import UIKit
import Metal
import MetalKit
import simd
import Accelerate

struct Uniforms {
    var lightPos: float2
}

class RenderResViewController: UIViewController, UIScrollViewDelegate {
    
    var PImage : ProcessingImage!
    var lightPos : float2 = [0.0, 0.0]
    var device: MTLDevice!
    
    var texture_PTM: [MTLTexture]!      // 6 + 2

    var metalLayer: CAMetalLayer!
    
    let vertexData: [Float] = [
        -1.0,  1.0, 0.0,
        -1.0, -1.0, 0.0,
        1.0, -1.0, 0.0,
        
        1.0,  1.0, 0.0,
        -1.0,  1.0, 0.0,
        1.0, -1.0, 0.0,
    ]
    
    var vertexBuffer: MTLBuffer!
    
    var pipelineState: MTLRenderPipelineState!
    
    var commandQueue: MTLCommandQueue!
    
    var timer: CADisplayLink!
    
    var fragmentProgramName = "displayTexture"
    
    //scroll
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var scrollImageView: UIImageView!
    //segment
    var fragmentProgram : MTLFunction?
    @IBOutlet weak var segmentSpecular: UISegmentedControl!
    
    @IBAction func segmentSpecular(_ sender: Any) {
        switch segmentSpecular.selectedSegmentIndex
        {
        case 0:
            self.fragmentProgramName = "displayTexture"
            pipelineStateInit()
            break
        case 1:
            self.fragmentProgramName = "displayTextureSpecular"
            pipelineStateInit()
            break
        default:
            break
        }
    }
    func pipelineStateInit() {
        
        device = MTLCreateSystemDefaultDevice()
        
        metalLayer = CAMetalLayer()          // 1
        metalLayer.device = device           // 2
        metalLayer.pixelFormat = .bgra8Unorm // 3
        metalLayer.framebufferOnly = true    // 4
        //metalLayer.frame = view.layer.frame  // 5
        let y1_view = scrollImageView.layer.frame.size.height
        let width_view = scrollImageView.layer.frame.size.width
        let height_view = width_view / 3 * 4
        metalLayer.frame = CGRect(x: 0, y: y1_view - height_view, width: width_view, height: height_view)
        
        scrollImageView.layer.addSublayer(metalLayer)   // 6
        
        // 1
        let defaultLibrary = device.makeDefaultLibrary()!
        fragmentProgram = defaultLibrary.makeFunction(name: fragmentProgramName)
        let vertexProgram = defaultLibrary.makeFunction(name: "mapTexture")
        
        // 2
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.sampleCount = 1
        pipelineStateDescriptor.depthAttachmentPixelFormat = .invalid
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // 3
        //pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        do {
            try pipelineState = device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        }
        catch {
            assertionFailure("Failed creating a render state pipeline. Can't render the texture without one.")
            return
        }
        commandQueue = device.makeCommandQueue()
        
        timer = CADisplayLink(target: self, selector: #selector(gameloop))
        timer.add(to: RunLoop.main, forMode: .default)
        
        // 必须放最后，因为前面还没有 初始化 device
        initTexture2D()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        pipelineStateInit()
        //swipe
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(self.respondToSwipeGesture))
        swipeRight.numberOfTouchesRequired = 2
        swipeRight.direction = UISwipeGestureRecognizer.Direction.right
        self.view.addGestureRecognizer(swipeRight)
        
        //scroll
        self.scrollView.minimumZoomScale = 1.0
        self.scrollView.maximumZoomScale = 6.0
        self.scrollView.delegate = self
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.scrollImageView
    }
    
    @objc func respondToSwipeGesture(gesture: UIGestureRecognizer) {
        if let swipeGesture = gesture as? UISwipeGestureRecognizer {
            switch swipeGesture.direction {
            case UISwipeGestureRecognizer.Direction.right:
                    print("Back!")
                    self.dismiss(animated: true, completion: nil)
            default:
                break
            }
        }
    }

    
    @IBAction func backToLastView() {
        print("Back!")
        self.dismiss(animated: true, completion: nil)
    }

    func initTexture2D() {
        let imagePixNum = self.PImage.imagePixNum
        let width = self.PImage.imageWidth
        let height = self.PImage.imageHeight
        var dataFloat = [Float](repeating: 0.0, count: imagePixNum)
        print("imagePixNum=", imagePixNum)
        print("width= ", width)
        print("height= ", height)
        let weightsDescription = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float, width: width, height: height, mipmapped: false)
        weightsDescription.usage = [.shaderRead,.shaderWrite,.pixelFormatView,.renderTarget]
        texture_PTM = [MTLTexture]()
        // load ptm.
        for k in 0...5 {
            // Double to float
            vDSP_vdpsp(&(self.PImage.matrixVSUG) + k*imagePixNum, 1, &dataFloat, 1, vDSP_Length(imagePixNum))
            
            let texture = device.makeTexture(descriptor: weightsDescription)
            texture!.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: &dataFloat, bytesPerRow: width * 4)
            texture_PTM.append(texture!)
        }
        
        // get cb
        let texture = device.makeTexture(descriptor: weightsDescription)
        texture!.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: self.PImage.cbcrFloat, bytesPerRow: width * 4)
        texture_PTM.append(texture!)
        
        // get cr
        let texture2 = device.makeTexture(descriptor: weightsDescription)
        texture2!.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: &(self.PImage.cbcrFloat) + imagePixNum*4, bytesPerRow: width * 4)
        texture_PTM.append(texture2!)
        
    }
    
    func render() {
        guard let drawable = metalLayer?.nextDrawable() else { return }
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: 0.0,
            green: 104.0/255.0,
            blue: 55.0/255.0,
            alpha: 1.0)
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        let renderEncoder = commandBuffer
            .makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.setRenderPipelineState(pipelineState)
     
        for i in 0...7 {
            renderEncoder.setFragmentTexture(texture_PTM[i], index: i)
        }
        
        var uniforms = Uniforms(lightPos: self.lightPos)
        renderEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 1)
        renderEncoder
            .drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)
        renderEncoder.endEncoding()
        
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    @objc func gameloop() {
        autoreleasepool {
            self.render()
        }
    }
    
    
    //Touch
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        //keyboard
        var location = CGPoint(x:0, y:0)
        
        self.view.endEditing(true)
        let touch = touches.first
        
        location = touch!.location(in: self.view)
        //375 x 667
        let height = scrollImageView.layer.frame.size.height
        let width = scrollImageView.layer.frame.size.width
        let scroll_origin_y = view.layer.frame.size.height - height
        if (location.y > scroll_origin_y){
            let x = Float((location.x - width / 2.0) / (width / 2))
            let y = Float((location.y - scroll_origin_y - height / 2.0) / (height / 2))
            
            if(x > -1 && x < 1 && y > -1 && y < 1 && (x * x + y * y <= 1)){
                lightPos.x = x
                lightPos.y = y
                print("touch pos = ", lightPos)
            }
        }
    }

}
