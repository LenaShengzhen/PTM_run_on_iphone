//
//  ImagesViewController.swift
//  RTIScan
//
//  Created by yang yuan on 2/9/19.
//  Copyright © 2019 Yuan Yang. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit
import BSImagePicker
import Photos
import Accelerate
//import Surge

class ImagesViewController: UIViewController  {
    
    @IBOutlet weak var imagePreview: UIImageView!
    
    var SelectedAssets = [PHAsset]()
    var PhotoArray = [RTIImage]()
    var PhotoPreviewIndex = 0
    
    var location = CGPoint(x:0, y:0)
    let dotLayer = CAShapeLayer();
    let sqaureUponImage = CAShapeLayer();
    let circleLayer = CAShapeLayer();
    
    //circle parameters
    var circlePostionX = 100.0;
    var circlePostionY = 100.0;
    var circleRadius = 50.0;
    
    let circlePostionXSmall = 100.0
    let circlePostionYSmall = 100.0;
    let circleRadiusSmall = 50.0;
    let circlePostionXLarge = 150.0
    let circlePostionYLarge = 150.0;
    let circleRadiusLarge = 100.0;
    
    var PImage : ProcessingImage!
    var img_width = 256
    var img_height = 342
    var img_scale = 1.0
    
    //select circle
    var SliderCircleXVar = 100
    var SliderCircleYVar = 300
    var SliderCircleRVar = 25
    var lightPos : float2 = [0.0, 0.0]
    
    
    //UI
    
    var CropImageOverlap : UIImageView!
    
    //enlarge light selecting view
    private var lightingSelectionEnlargeView: UIView!
    
    @IBOutlet weak var ViewPositionY: UILabel!
    @IBOutlet weak var ViewPositionX: UILabel!
    @IBAction func imageProcess(_ sender: Any) {
        if(PImage == nil){
            PImage = ProcessingImage(toProcessImage: PhotoArray, imageNum : PhotoArray.count, imageWidth : Int(PhotoArray[0].photoImage.size.width), imageHeight : Int(PhotoArray[0].photoImage.size.height))
        }
        
        //form matrix change by 2019-11
        PImage.calcBigMatrixOnce()
    }
  
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBAction func ImgScaleControl(_ sender: UISegmentedControl) {
        switch segmentedControl.selectedSegmentIndex
        {
        case 0:
            img_width = 256
            img_height = 342
            img_scale = 1.0
            break
        case 1:
            img_width = 667 //Int(256.0 * 2.6)
            img_height = 889 //Int(342 * 2.6)
            img_scale = 2.6
            break
        default:
            break
        }
    }
    @IBAction func SliderCircleR(_ sender: UISlider) {
        if circleRadius == circleRadiusSmall{
            SliderCircleRVar = Int(sender.value)
            drawSelectedCircle()
        }
    }
    @IBAction func SliderCircleXMinus(_ sender: Any) {
        if circleRadius == circleRadiusSmall{
            SliderCircleXVar -= 1
            drawSelectedCircle()
        }
    }
    @IBAction func SliderCircleXAdd(_ sender: Any) {
        if circleRadius == circleRadiusSmall{
            SliderCircleXVar += 1
            drawSelectedCircle()
        }
    }
    @IBAction func SliderCircleYMinus(_ sender: Any) {
        if circleRadius == circleRadiusSmall{
            SliderCircleYVar -= 1
            print("hxt-SliderCircleYVar = ", SliderCircleYVar)
            drawSelectedCircle()
        }
    }
    @IBAction func SliderCircleYAdd(_ sender: Any) {
        if circleRadius == circleRadiusSmall{
            SliderCircleYVar += 1
            drawSelectedCircle()
        }
    }
    @IBAction func LocateLight(_ sender: Any) {
        if(PImage == nil){
            PImage = ProcessingImage(toProcessImage: PhotoArray, imageNum : PhotoArray.count, imageWidth : Int(PhotoArray[0].photoImage.size.width), imageHeight : Int(PhotoArray[0].photoImage.size.height))
        }
        PImage.LocateLight(ballR_in: SliderCircleRVar, ballX_in: SliderCircleXVar, ballY_in: SliderCircleYVar - 218, scale: img_scale)
        
    }
    @IBOutlet weak var SelectLightBtn: UIButton!
    
    @IBAction func SelectLight(_ sender: Any) {
        
    }
    @IBOutlet weak var imageRenderFilename: UITextField!
    @IBAction func imageRenderStore(_ sender: Any) { //VertexX
        let text: String = imageRenderFilename.text!
        print(text)
        if PImage != nil {
            PImage.savePTM(fileName: text)
        }
        
        //Alert box
        let alert = UIAlertController(title: "Saved!", message: "PTM file saved!", preferredStyle: UIAlertController.Style.alert)
        // add an action (button)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        // show the alert
        self.present(alert, animated: true, completion: nil)
        
    }
    @IBAction func imageRenderRead(_ sender: Any) {
        let text: String = imageRenderFilename.text!
        if PImage != nil {
            PImage.readPTM(fileName: text)
        }
        else {
            PImage = ProcessingImage(toProcessImage: PhotoArray, imageNum : PhotoArray.count, imageWidth : img_width, imageHeight : img_height)
            PImage.readPTM(fileName: text)
        }
        PImage.flagFinishRender = true
        
        //Alert box
        let alert = UIAlertController(title: "Done!", message: "Successfully importing PTM file!", preferredStyle: UIAlertController.Style.alert)
        // add an action (button)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        // show the alert
        self.present(alert, animated: true, completion: nil)
    }
    @IBAction func previousImage(_ sender: Any) {
        if !PhotoArray.isEmpty {
            if PhotoPreviewIndex > 0 {
                PhotoPreviewIndex -= 1
            }
            else {
                PhotoPreviewIndex = PhotoArray.count - 1
            }
            self.imagePreview.image = PhotoArray[PhotoPreviewIndex].photoImage
            
            UIGraphicsBeginImageContextWithOptions(CGSize(width: CGFloat(Int(Double(SliderCircleRVar) * 2.0 * img_scale)), height: CGFloat(Int(Double(SliderCircleRVar) * 2.0 * img_scale))), true, CGFloat(1.0))
            PhotoArray[PhotoPreviewIndex].photoImage.draw(at: CGPoint(x: -Double(SliderCircleXVar - SliderCircleRVar) * img_scale, y: (-Double(SliderCircleYVar - SliderCircleRVar) * img_scale + 218.0 * img_scale ) ))
            let croppedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            self.CropImageOverlap.image = croppedImage
            self.view.addSubview(CropImageOverlap)
            view.layer.addSublayer(circleLayer)
            
            
            //drawing plots
            dotLayer.path = UIBezierPath(ovalIn: CGRect(x: PhotoArray[PhotoPreviewIndex].lightPositionX * CGFloat(circleRadius) + CGFloat(circlePostionX), y: PhotoArray[PhotoPreviewIndex].lightPositionY * CGFloat(circleRadius) + CGFloat(circlePostionY), width: 2, height: 2)).cgPath;
            dotLayer.strokeColor = UIColor.green.cgColor
            view.layer.addSublayer(dotLayer)
            
            
        }
    }
    
    @IBAction func NextImage(_ sender: Any) {
        if !PhotoArray.isEmpty {	
            if PhotoPreviewIndex < PhotoArray.count - 1 {
                PhotoPreviewIndex += 1
            }
            else {
                PhotoPreviewIndex = 0
            }
            self.imagePreview.image = PhotoArray[PhotoPreviewIndex].photoImage
            
            //crop image
            UIGraphicsBeginImageContextWithOptions(CGSize(width: CGFloat(Int(Double(SliderCircleRVar) * 2.0 * img_scale)), height: CGFloat(Int(Double(SliderCircleRVar) * 2.0 * img_scale))), true, CGFloat(1.0))
            PhotoArray[PhotoPreviewIndex].photoImage.draw(at: CGPoint(x: -Double(SliderCircleXVar - SliderCircleRVar) * img_scale, y: (-Double(SliderCircleYVar - SliderCircleRVar) * img_scale + 218.0 * img_scale ) ))
            let croppedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            self.CropImageOverlap.image = croppedImage
            self.view.addSubview(CropImageOverlap)
            view.layer.addSublayer(circleLayer)
            //drawing plots
            dotLayer.path = UIBezierPath(ovalIn: CGRect(x: PhotoArray[PhotoPreviewIndex].lightPositionX * CGFloat(circleRadius) + CGFloat(circlePostionX), y: PhotoArray[PhotoPreviewIndex].lightPositionY * CGFloat(circleRadius) + CGFloat(circlePostionY), width: 2, height: 2)).cgPath;
            dotLayer.strokeColor = UIColor.green.cgColor
            view.layer.addSublayer(dotLayer)
            
        }
    }
    
    @IBAction func importImage(_ sender: Any) {
        let vc = BSImagePickerViewController()
        
        bs_presentImagePickerController(vc, animated: true,
                                        select: { (asset: PHAsset) -> Void in
                                             print("Selected: \(asset)")
        }, deselect: { (asset: PHAsset) -> Void in
            // User deselected an assets.
            // Do something, cancel upload?
        }, cancel: { (assets: [PHAsset]) -> Void in
            // User cancelled. And this where the assets currently selected.
        }, finish: { (assets: [PHAsset]) -> Void in
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // User finished with these assets
            for i in 0..<assets.count
            {
                self.SelectedAssets.append(assets[i])
                
            }
            
            self.convertAssetToImages()
            
            let endTime1 = CFAbsoluteTimeGetCurrent()
            print(String(format: "convertAssetToImages 的执行时长为: %f 毫秒 ms", (endTime1 - startTime)*1000))
        }, completion: nil)
        
    }
    
    @IBAction func backToLastView() {
        print("Back!")
        self.dismiss(animated: true, completion: nil)
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "RenderResSegue"{
            
            let destView = segue.destination as! RenderResViewController
            destView.PImage = self.PImage
        }
    }
    @IBAction func RenderView(_ sender: Any) {
        self.performSegue(withIdentifier: "RenderResSegue", sender: self)
    }
    
    //Touch
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        //keyboard
        self.view.endEditing(true)
        
        let touch = touches.first
        
        location = touch!.location(in: self.view)
        
        //touch in ball
        let dist = (location.x - CGFloat(circlePostionX))  *  (location.x - CGFloat(circlePostionX))
                 + (location.y - CGFloat(circlePostionY))  *  (location.y - CGFloat(circlePostionY))

        if  dist.squareRoot() <= CGFloat(circleRadius) {
            //drawing plots
            dotLayer.path = UIBezierPath(ovalIn: CGRect(x: location.x, y: location.y, width: 2, height: 2)).cgPath;
            dotLayer.strokeColor = UIColor.green.cgColor
            view.layer.addSublayer(dotLayer)
            
            ViewPositionY.text = location.y.description
            ViewPositionX.text = location.x.description
            
            if (PImage != nil && PImage.flagFinishRender == true) {
                PImage.renderImageResult(l_u_raw: Double(location.x) - Double(circlePostionX), l_v_raw: Double(location.y) - Double(circlePostionY))
                self.imagePreview.image = PImage.toProcessImage[0].photoImage
                
            }
            else if !PhotoArray.isEmpty {
                PhotoArray[PhotoPreviewIndex].lightPositionX = (location.x - CGFloat(circlePostionX)) / CGFloat(circleRadius)
                PhotoArray[PhotoPreviewIndex].lightPositionY = (location.y - CGFloat(circlePostionY)) / CGFloat(circleRadius)
            }
            

        }
        
        //select ball
        if circleRadius == circleRadiusSmall {
            print(location)
            if location.x <= 256 && location.y > 218 && location.y < 412 + 218 {
                SliderCircleXVar = Int(location.x)
                SliderCircleYVar = Int(location.y)
            }
            drawSelectedCircle()
        }
        
    }
    
    //draw circle on the image
    func drawSelectedCircle() {
        sqaureUponImage.path = UIBezierPath(ovalIn: CGRect(x: Double(SliderCircleXVar - SliderCircleRVar), y: Double(SliderCircleYVar - SliderCircleRVar), width: Double(SliderCircleRVar) * 2, height: Double(SliderCircleRVar) * 2)).cgPath;
        sqaureUponImage.opacity = 0.5
        view.layer.addSublayer(sqaureUponImage)
    }
    //Convert Helper
    func convertAssetToImages() -> Void {
        
        if SelectedAssets.count != 0{
            
            
            for i in 0..<SelectedAssets.count{
                
                let manager = PHImageManager.default()
                let option = PHImageRequestOptions()
                var thumbnail = UIImage()
                option.isSynchronous = true
                option.resizeMode = PHImageRequestOptionsResizeMode(rawValue: 2)!
                manager.requestImage(for: SelectedAssets[i], targetSize: CGSize(width: img_width, height: img_height), contentMode: PHImageContentMode.aspectFill, options: option, resultHandler: {(result, info)->Void in
                    thumbnail = result!
                    
                })
                
                let data = thumbnail.jpegData(compressionQuality: 1.0)  // 0.7 old code is small the pic
                //let newImage = UIImage(data: data!)
                
                let photoArrayTemp = RTIImage(photoImage: UIImage(data: data!)!)
                self.PhotoArray.append(photoArrayTemp as RTIImage)
                //todo scale
                print("?",photoArrayTemp.photoImage.size)
                
            }
            
        }
        
        
        print("complete photo array \(self.PhotoArray)")
    }
    
    @objc func SelectLightBtnTap() {
        
        print("Tap happend")
        if circleRadius != circleRadiusLarge {
            circleRadius = circleRadiusLarge
            circlePostionX = circlePostionXLarge
            circlePostionY = circlePostionYLarge
        }
        else{
            circleRadius = circleRadiusSmall
            circlePostionX = circlePostionXSmall
            circlePostionY = circlePostionYSmall
        }
        
        CropImageOverlap.frame = CGRect(x: circlePostionX - circleRadius, y: circlePostionY - circleRadius, width: circleRadius * 2, height: circleRadius * 2)
        
        
        //black circle
        circleLayer.path = UIBezierPath(ovalIn: CGRect(x: circlePostionX - circleRadius, y: circlePostionY - circleRadius, width: circleRadius * 2, height: circleRadius * 2)).cgPath;
        //drawing plots
        dotLayer.path = UIBezierPath(ovalIn: CGRect(x: PhotoArray[PhotoPreviewIndex].lightPositionX * CGFloat(circleRadius) + CGFloat(circlePostionX), y: PhotoArray[PhotoPreviewIndex].lightPositionY * CGFloat(circleRadius) + CGFloat(circlePostionY), width: 2, height: 2)).cgPath;
        dotLayer.strokeColor = UIColor.green.cgColor
        view.layer.addSublayer(dotLayer)
    }
    
    @objc func SelectLightBtnLong() {
        
        print("Long press")
        //loadLightingSelectionSubview()
    }
    private func loadLightingSelectionSubview() {

        
        lightingSelectionEnlargeView.isHidden = false
        print("showing!!")
        
        // any other objects should be tied to this view as superView
        // for example adding this okayButton
        
        let okayButtonFrame = CGRect(x: 40, y: 100, width: 50, height: 50)
        let okayButton = UIButton(frame: okayButtonFrame )
        
        // here we are adding the button its superView
        lightingSelectionEnlargeView.addSubview(okayButton)
        
        okayButton.addTarget(self, action: #selector(self.didPressButtonFromCustomView), for:.touchUpInside)
        
    }
    @objc func didPressButtonFromCustomView(sender:UIButton) {
        print("touched")
        lightingSelectionEnlargeView.isHidden = true
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        

        //draw black circle
        circleLayer.path = UIBezierPath(ovalIn: CGRect(x: circlePostionX - circleRadius, y: circlePostionY - circleRadius, width: circleRadius * 2, height: circleRadius * 2)).cgPath;
        circleLayer.opacity = 0.5
        view.layer.addSublayer(circleLayer)
        
        //create new image view
        CropImageOverlap  = UIImageView(frame: CGRect(x: circlePostionX - circleRadius, y: circlePostionY - circleRadius, width: circleRadius * 2, height: circleRadius * 2));
        
        //select light button
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector (SelectLightBtnTap))  //Tap function will call when user tap on button
        let longGesture = UILongPressGestureRecognizer(target: self, action: #selector(SelectLightBtnLong))  //Long function will call when user long press on button.
        longGesture.minimumPressDuration = 1.0
        tapGesture.numberOfTapsRequired = 1
        SelectLightBtn.addGestureRecognizer(tapGesture)
        SelectLightBtn.addGestureRecognizer(longGesture)
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}
