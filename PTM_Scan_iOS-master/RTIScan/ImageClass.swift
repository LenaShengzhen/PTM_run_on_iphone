//
//  ImageClass.swift
//  RTIScan
//
//  Created by yang yuan on 2/17/19.
//  Copyright © 2019 Yuan Yang. All rights reserved.
//

import Foundation
import UIKit

import Foundation
import Accelerate

extension UIImage {
    func getPixelColor(pos: CGPoint) -> UIColor {
        
        let pixelData = self.cgImage!.dataProvider!.data
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        
        let pixelInfo: Int = ((Int(self.size.width) * Int(pos.x)) + Int(pos.y)) * 4
        
        let r = CGFloat(data[pixelInfo]) / CGFloat(255.0)
        let g = CGFloat(data[pixelInfo+1]) / CGFloat(255.0)
        let b = CGFloat(data[pixelInfo+2]) / CGFloat(255.0)
        
        return UIColor(red: r, green: g, blue: b, alpha: 0.0)
    }
}

//images
class RTIImage {
    
    var photoImage : UIImage
    var lightPositionX : CGFloat
    var lightPositionY : CGFloat
    var lightPositionZ : CGFloat
    
    init(photoImage : UIImage) {
        self.photoImage = photoImage
        self.lightPositionX = 0.0
        self.lightPositionY = 0.0
        self.lightPositionZ = 0.0
    }
}

class ProcessingImage {
    
    //test
    typealias Matrix = Array<[Double]>
    typealias Vector = [Double]
    
    var matrixA = Matrix() //nums * 6 just one
    
    // new add on 2019-11
    var vectorGray : [Double]   // nums [height*width*imageNum] channel:gray
    var matrixVSUG : [Double]   // [6*height*width] save:PTM 的值。
    var cbcrFloat : [Float]     // save cbcr [height*width*2]
    public var imagePixNum : Int // = imageWidth * imageHeight
    
    let imageNum : Int
    var imageWidth : Int
    var imageHeight : Int
    
    var LightXRender = 0.5
    var LightYRender = 0.5
    
    var flagFinishRender : Bool = false
    var renderingBufferCount : Int = 5
    var renderingBufferStep : Double = 0.4
    
    var bias : [Double]
    var scale : [Double]
    
    let toProcessImage : [RTIImage]
    
    init(toProcessImage: [RTIImage], imageNum : Int, imageWidth : Int, imageHeight : Int) {
        
        let endTime1 = CFAbsoluteTimeGetCurrent()
        
        self.toProcessImage = toProcessImage
        self.imageNum = imageNum
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.imagePixNum = imageWidth*imageHeight
        
        //initialized matrix
        let temp = [Double](repeating: 0.0, count: imageNum)
        self.matrixA = Matrix(repeating: temp, count: 6)
        
        // new code add on 2019-12-01
        self.vectorGray = [Double](repeating: 0.0, count: imageWidth*imageHeight*imageNum)
        self.matrixVSUG = [Double](repeating: 0.0, count: 6 * imageWidth*imageHeight)
        self.cbcrFloat = [Float](repeating: 0.0, count: imagePixNum*2)
     
        self.scale = [1, 1, 1, 1, 1, 1]
        self.bias = [0, 0, 0, 0, 0, 0]
        
        let endTime2 = CFAbsoluteTimeGetCurrent()
        print(String(format: "ProcessingImage 的执行时长为: %f 毫秒 ms", (endTime2 - endTime1)*1000))
    }
    
    // add on 2019.12.01
    func savePTM(fileName : String) {
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            
            // save matrixVSUG
            let url = dir.appendingPathComponent(fileName + "_matrixVSUG.rti")
            do {
                let data = try PropertyListSerialization.data(fromPropertyList: self.matrixVSUG, format: .binary, options: 0)
                try data.write(to: url, options: .atomic)
            }
            catch { print(error) }
            
            // save cbcr
            let url_cbcrFloat = dir.appendingPathComponent(fileName + "_cbcrFloat.rti")
            do {
                let data = try PropertyListSerialization.data(fromPropertyList: self.cbcrFloat, format: .binary, options: 0)
                try data.write(to: url_cbcrFloat, options: .atomic)
            }
            catch { print(error) }
            
            // save height
            let url_imageHeight = dir.appendingPathComponent(fileName + "_imageHeight.rti")
            do {
                let data = try PropertyListSerialization.data(fromPropertyList: self.imageHeight, format: .binary, options: 0)
                try data.write(to: url_imageHeight, options: .atomic)
            }
            catch { print(error) }
        }
    }
    
    func readPTM(fileName : String) {
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let url = dir.appendingPathComponent(fileName + "_matrixVSUG.rti")
            do {
                let data = try Data(contentsOf: url)
                self.matrixVSUG = try PropertyListSerialization.propertyList(from: data, format: nil) as! [Double]
            }
            catch { print(error) }
            
            let url_cbcrFloat = dir.appendingPathComponent(fileName + "_cbcrFloat.rti")
            do {
                let data = try Data(contentsOf: url_cbcrFloat)
                self.cbcrFloat = try PropertyListSerialization.propertyList(from: data, format: nil) as! [Float]
            }
            catch { print(error) }
            
            let url_imageHeight = dir.appendingPathComponent(fileName + "_imageHeight.rti")
            do {
                let data = try Data(contentsOf: url_imageHeight)
                self.imageHeight = try PropertyListSerialization.propertyList(from: data, format: nil) as! Int
                self.imageWidth = self.cbcrFloat.count / (2 * self.imageHeight)
                self.imagePixNum = self.imageWidth * self.imageHeight
            }
            catch { print(error) }
        }
    }
    
    func LocateLight(ballR_in : Int, ballX_in : Int, ballY_in : Int, scale : Double) {
        
        let endTime0 = CFAbsoluteTimeGetCurrent()
        
        let ballR = Int(Double(ballR_in) * scale)
        let ballY = Int(Double(ballY_in) * scale)
        let ballX = Int(Double(ballX_in) * scale)
        for index in 0..<imageNum {
            
            var max = 0.0
            let img = toProcessImage[index].photoImage
            let pixelData = img.cgImage!.dataProvider!.data
            let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
            //print(ballX, ballY, ballR)
            for x in Int(ballX - ballR)...Int(ballX + ballR){
                for y in Int(ballY - ballR)...Int(ballY + ballR) {
                    let dist_X = (x - ballX) * (x - ballX)
                    let dist_Y = (y - ballY) * (y - ballY)
                    let dist = dist_X + dist_Y
                    if(dist  - ballR * ballR <= 0) {
                        let pixelInfo: Int = ((imageWidth * y) + x) * 4
                        
                        let r = Double(data[pixelInfo])     / Double(255.0)
                        let g = Double(data[pixelInfo + 1]) / Double(255.0)
                        let b = Double(data[pixelInfo + 2]) / Double(255.0)
                        let light = r * 0.2126 + g * 0.7152 + b * 0.0722
                        //print(x,y,r,g,b, (Double(x) - Double(ballX)) / (Double(ballR)), (Double(y) - Double(ballY)) / (Double(ballR)))
                        if(max <= light){
                            max = light
                            self.toProcessImage[index].lightPositionX = CGFloat((Double(x) - Double(ballX)) / (Double(ballR)))
                            self.toProcessImage[index].lightPositionY = CGFloat((Double(y) - Double(ballY)) / (Double(ballR)))
                            
                            //print(x,y,max)
                        }
                    }
                }
            }
            //print(max, toProcessImage[index].lightPositionX , toProcessImage[index].lightPositionY)
        }
        
        let endTime1 = CFAbsoluteTimeGetCurrent()
        print(String(format: "LocateLight() 的执行时长为: %f 毫秒 ms", (endTime1 - endTime0)*1000))
    }
    
    func renderImageResult(l_u_raw : Double, l_v_raw : Double) {

    }
    
    public func calcMatrixA() {
         //matrixA
        for index in 0..<imageNum {
           
            let lu = toProcessImage[index].lightPositionX
            let lv = toProcessImage[index].lightPositionY
            //print("lu and lv", lu, lv)
            matrixA[0][index] = Double(lu * lu)
            matrixA[1][index] = Double(lv * lv)
            matrixA[2][index] = Double(lu * lv)
            matrixA[3][index] = Double(lu)
            matrixA[4][index] = Double(lv)
            matrixA[5][index] = Double(1.0)
        }
    }
    
    public func calcYcc() {
        let endTimess = CFAbsoluteTimeGetCurrent()
        // 只取rgb三个通道的值，不要第4个通道。 - 会反复 覆盖 使用。
        var dataDouble = [Double](repeating: 0.0, count: imagePixNum*3)
        
        let endTimeee = CFAbsoluteTimeGetCurrent()
        // 计算 ycc 需要的系数。
        let yCoe : [Double] = [0.2126/255.0, 0.7152/255.0, 0.0722/255.0]
        
        let endTimeycc = CFAbsoluteTimeGetCurrent()
        print(String(format: "calcYcc(): dataDouble--init 的执行时长为: %f 毫秒 ms", (endTimeee - endTimess)*1000))
        print(String(format: "calcYcc(): yCoe--init 的执行时长为: %f 毫秒 ms", (endTimeycc - endTimeee)*1000))
        
        var looptime1 = 0.0
        var looptime2 = 0.0
        var looptime3 = 0.0
        for index in 0..<imageNum {
            //print("Processing image", index)
            
            let endTime0 = CFAbsoluteTimeGetCurrent()
            //matrixY
            let img = toProcessImage[index].photoImage
            let pixelData = img.cgImage!.dataProvider!.data
            let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
            
            let endTime1 = CFAbsoluteTimeGetCurrent()
            looptime1 = looptime1 + endTime1 - endTime0
            // 分别 get r,g,b,  其中 data 中每4个数据，取1一个出来用，dataDouble 中每1个数据取1来存结果。
            /*  存储格式：
                r, r, r, r, ...
                g, g, g, g, ...
                b, b, b, b, ...
             */
            vDSP_vfltu8D(data, 4, &dataDouble, 1, vDSP_Length(imagePixNum))
            vDSP_vfltu8D(data+1, 4, &dataDouble+1*imagePixNum, 1, vDSP_Length(imagePixNum))
            vDSP_vfltu8D(data+2, 4, &dataDouble+2*imagePixNum, 1, vDSP_Length(imagePixNum))
            
            let endTime2 = CFAbsoluteTimeGetCurrent()
            looptime2 = looptime2 + endTime2 - endTime1
            // luminance : let ycc = r * 0.2126 + g * 0.7152 + b * 0.0722
            // 矩阵乘法：yCoe[0.2126, 0.7152, 0.0722] * dataDouble[r,g,b]  = ycc
            //https://developer.apple.com/documentation/accelerate/vimage/vimage_operations/conversion/understanding_ypcbcr_image_formats
            vDSP_mmulD(yCoe, 1, dataDouble, 1, &vectorGray+imagePixNum*index, 1, vDSP_Length(1), vDSP_Length(imagePixNum), vDSP_Length(3))
            
            
            let endTime3 = CFAbsoluteTimeGetCurrent()
            looptime3 = looptime3 + endTime3 - endTime2
            //cbcr
            if(index == 0) {
                // get b
                vDSP_vdpsp(&dataDouble+2*imagePixNum, 1, &cbcrFloat, 1, vDSP_Length(imagePixNum))
                // get r
                vDSP_vdpsp(dataDouble, 1, &cbcrFloat + imagePixNum, 1, vDSP_Length(imagePixNum))
                // 向量和常数相乘
                var mod: Float = 1.0/255.0
                
                // 向量对应相加 : cb = b - ycc, cr = r - ycc
                var yccFloat = [Float](repeating: 0.0, count: imagePixNum)
                vDSP_vdpsp(vectorGray, 1, &yccFloat, 1, vDSP_Length(imagePixNum))
                
                // zsj
                //Multiplies vector A by scalar B and then subtracts vector C from the products. Results are stored in vector D.
                vDSP_vsmsb (cbcrFloat,
                1,
                &mod,
                &yccFloat,
                1,
                &cbcrFloat,
                1,
                vDSP_Length(imagePixNum));

                vDSP_vsmsb (&cbcrFloat + imagePixNum,
                1,
                &mod,
                &yccFloat,
                1,
                &cbcrFloat + imagePixNum,
                1,
                vDSP_Length(imagePixNum));
                
            }

        }
        
        print(String(format: "calcYcc(): looptime1 的执行时长为: %f 毫秒 ms", (looptime1)*1000))
        print(String(format: "calcYcc(): looptime2 的执行时长为: %f 毫秒 ms", (looptime2)*1000))
        print(String(format: "calcYcc(): looptime3 的执行时长为: %f 毫秒 ms", (looptime3)*1000))
    }
    
    // 先把 svd 3个矩阵乘在一起之后，再和大矩阵进行相乘。
    public func calcBigMatrixOnce() {
        
        let endTime0 = CFAbsoluteTimeGetCurrent()
        calcMatrixA()

        let endTime1 = CFAbsoluteTimeGetCurrent()
        calcYcc()

        let endTime2 = CFAbsoluteTimeGetCurrent()
        print(String(format: "calcYcc() 的总执行时长为: %f 毫秒 ms", (endTime2 - endTime1)*1000))
        print(String(format: "calcMatrixA() 的执行时长为: %f 毫秒 ms", (endTime1 - endTime0)*1000))
        
        
        var uTrans : [Double]
        var s : [Double]    // 这里输出的是 s‘ transpose matrix
        var v : [Double]
        (uTrans,s,v) = svdvector(inputMatrix: matrixA)
      
        // s‘ inverse matrix = s’ transpose matrix 的 特征值 都取倒数。
        // s‘ inverse matrix: row: 6, col: imageNum
        for index in 0..<6 {
            s[index*imageNum + index] = 1.0 / s[index*imageNum + index]
        }
        
        // sT * uT
        var matrixSU = [Double](repeating: 0.0, count: 6 * imageNum)
        vDSP_mmulD(s, 1, uTrans, 1, &matrixSU, 1, vDSP_Length(6), vDSP_Length(imageNum), vDSP_Length(imageNum))
        
        // v * matrixSU
        var matrixVSU = [Double](repeating: 0.0, count: 6 * imageNum)
        vDSP_mmulD(v, 1, matrixSU, 1, &matrixVSU, 1, vDSP_Length(6), vDSP_Length(imageNum), vDSP_Length(6))
        
        let endTime3 = CFAbsoluteTimeGetCurrent()
        print(String(format: "计算 SVD分解 + VSU矩阵相乘 的执行时长为: %f 毫秒 ms", (endTime3 - endTime2)*1000))
        
        
        // matrixVSUG = matrixVSU * G.  v' row = v' col =  6.
        vDSP_mmulD(matrixVSU, 1, vectorGray, 1, &matrixVSUG, 1, vDSP_Length(6), vDSP_Length(imageHeight*imageWidth), vDSP_Length(imageNum))
        //print(String(format:"matrixVSUG.count = : %d", matrixVSUG.count))
        
        let endTime4 = CFAbsoluteTimeGetCurrent()
        print(String(format: "计算 大矩阵 乘法 的执行时长为: %f 毫秒 ms", (endTime4 - endTime3)*1000))
        print("imageHeight = ", imageHeight)
        print("imageWidth = ", imageWidth)
        print(String(format:"matrixVSUG.count = : %d", matrixVSUG.count))
        
        print("matrix calculation completed")
    }
    
    // new-2019-11
    public func svdvector(inputMatrix:Matrix) -> (u:[Double], s:[Double], v:[Double]) {
        let m = inputMatrix[0].count
        let n = inputMatrix.count
        let x = inputMatrix.reduce([], {$0+$1})
        var JOBZ = Int8(UnicodeScalar("A").value)
        var JOBU = Int8(UnicodeScalar("A").value)
        var JOBVT = Int8(UnicodeScalar("A").value)
        var M = __CLPK_integer(m)
        var N = __CLPK_integer(n)
        var A = x
        var LDA = __CLPK_integer(m)
        var S = [__CLPK_doublereal](repeating: 0.0, count: min(m,n))
        var U = [__CLPK_doublereal](repeating: 0.0, count: m*m)
        var LDU = __CLPK_integer(m)
        var VT = [__CLPK_doublereal](repeating: 0.0, count: n*n)
        var LDVT = __CLPK_integer(n)
        let lwork = min(m,n)*(6+4*min(m,n))+max(m,n)
        var WORK = [__CLPK_doublereal](repeating: 0.0, count: lwork)
        var LWORK = __CLPK_integer(lwork)
        var IWORK = [__CLPK_integer](repeating: 0, count: 8*min(m,n))
        var INFO = __CLPK_integer(0)
        if m >= n {
            dgesdd_(&JOBZ, &M, &N, &A, &LDA, &S, &U, &LDU, &VT, &LDVT, &WORK, &LWORK, &IWORK, &INFO)
        } else {
            dgesvd_(&JOBU, &JOBVT, &M, &N, &A, &LDA, &S, &U, &LDU, &VT, &LDVT, &WORK, &LWORK, &INFO)
        }
        var s = [Double](repeating: 0.0, count: m*n)
        for ni in 0...(min(m,n)-1) {
            s[ni*m+ni] = S[ni]
        }
        
        var outputU:[Double]
        var outputS:[Double]
        var outputV:[Double]
        
        outputU = Array(U[0..<m*m])
        outputS = Array(s[0..<n*m])
        outputV = Array(VT[0..<n*n])
        
        return (outputU, outputS, outputV)
    }
}
