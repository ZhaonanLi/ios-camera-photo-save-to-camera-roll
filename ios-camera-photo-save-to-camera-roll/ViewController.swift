//
//  ViewController.swift
//  ios-camera-photo-save-to-camera-roll
//
//  Created by Zhaonan Li on 9/10/16.
//  Copyright © 2016 Zhaonan Li. All rights reserved.
//

import UIKit
import GLKit
import Photos
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var takePhotoBtn: UIButton!
    
    var stillImageOutput: AVCaptureStillImageOutput?
    
    lazy var glContext: EAGLContext = {
        let glContext = EAGLContext(API: .OpenGLES2)
        return glContext
    }()
    
    lazy var glView: GLKView = {
        let glView = GLKView(
            frame: CGRect(
                x: 0,
                y: 0,
                width: self.cameraView.bounds.width,
                height: self.cameraView.bounds.height),
            context: self.glContext)
        
        glView.bindDrawable()
        return glView
    }()
    
    lazy var ciContext: CIContext = {
        let ciContext = CIContext(EAGLContext: self.glContext)
        return ciContext
    }()
    
    lazy var cameraSession: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = AVCaptureSessionPresetPhoto
        return session
    }()
    
    lazy var photoFullPath: String = {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
        let photoFullPath = documentsPath.stringByAppendingString("/test_camera_capture_photo.png")
        let fileManager = NSFileManager.defaultManager()
        if fileManager.fileExistsAtPath(photoFullPath) {
            do {
                try fileManager.removeItemAtURL(NSURL(fileURLWithPath: photoFullPath))
            } catch let error as NSError {
                print(error)
            }
        }
        
        return photoFullPath
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        setupCameraSession()
    }
    
    override func viewDidAppear(animated: Bool) {
        cameraView.addSubview(glView)
        cameraSession.startRunning()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    
    func setupCameraSession() {
        let captureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo) as AVCaptureDevice
        
        do {
            cameraSession.beginConfiguration()
            
            let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
            if cameraSession.canAddInput(deviceInput) {
                cameraSession.addInput(deviceInput)
            }
            
            stillImageOutput = AVCaptureStillImageOutput()
            stillImageOutput!.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
            if cameraSession.canAddOutput(stillImageOutput) {
                cameraSession.addOutput(stillImageOutput)
            }
            
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.videoSettings = [
                (kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(unsignedInt: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            ]
            videoOutput.alwaysDiscardsLateVideoFrames = true
            if cameraSession.canAddOutput(videoOutput) {
                cameraSession.addOutput(videoOutput)
            }
            
            cameraSession.commitConfiguration()
            
            let videoStreamingQueue = dispatch_queue_create("com.somedomain.videoStreamingQueue", DISPATCH_QUEUE_SERIAL)
            videoOutput.setSampleBufferDelegate(self, queue: videoStreamingQueue)
            
        } catch let error as NSError {
            print(error)
        }
    }
    
    
    
    
    

    @IBAction func takePhoto(sender: AnyObject) {
        
        if let videoConnection = stillImageOutput!.connectionWithMediaType(AVMediaTypeVideo) {
            stillImageOutput!.captureStillImageAsynchronouslyFromConnection(videoConnection, completionHandler: { (cmSampleBuffer: CMSampleBuffer!, error) in
            
                if error != nil {
                    print(error)
                    return
                }
                
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(cmSampleBuffer)
                let ciImage = CIImage(data: imageData)
                
                // Apply filter on ciImage here.////////////////////////////////////////////////////////
                // Rotate the ciImage 90 degrees to right.
                var affineTransform = CGAffineTransformMakeTranslation(ciImage!.extent.width / 2, ciImage!.extent.height / 2)
                affineTransform = CGAffineTransformRotate(affineTransform, CGFloat(-1 * M_PI_2))
                affineTransform = CGAffineTransformTranslate(affineTransform, -ciImage!.extent.width / 2, -ciImage!.extent.height / 2)
                
                let transformFilter = CIFilter(
                    name: "CIAffineTransform",
                    withInputParameters: [
                        kCIInputImageKey: ciImage!,
                        kCIInputTransformKey: NSValue(CGAffineTransform: affineTransform)
                    ]
                )
                
                let transformedCIImage = transformFilter!.outputImage!
                // Finish applying filter on ciImage./////////////////////////////////////////////////////
                
                
                
                let cgImage = self.ciContext.createCGImage(transformedCIImage, fromRect: transformedCIImage.extent)
                let filteredUIImage = UIImage(CGImage: cgImage, scale: 1.0, orientation: UIImageOrientation.Up)
                
                // UIImageJPEGRepresentation(filteredUIImage, 1.0)!.writeToFile(self.photoFullPath, atomically: true)
                UIImagePNGRepresentation(filteredUIImage)!.writeToFile(self.photoFullPath, atomically: true)

                PHPhotoLibrary.sharedPhotoLibrary().performChanges(
                    {
                        PHAssetChangeRequest.creationRequestForAssetFromImageAtFileURL(NSURL(fileURLWithPath: self.photoFullPath))}) { completed, error in
                            if error != nil {
                                print("Cannot move the photo from file to camera roll, error=\(error)")
                                return
                            }
                        
                            if completed {
                                print("Succeed in moving the photo from the file to camera roll.")
                            }
                        }
                    }
                )
        }
    }
    
    
    
    
    
    
    
    
    
    
    
    // Implement the delegate method
    // Interface: AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        // Here we can collect the frames , and process them.

        
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let ciImage = CIImage(CVPixelBuffer: pixelBuffer!)
        
        // Rotate the ciImage 90 degrees to right.
        var affineTransform = CGAffineTransformMakeTranslation(ciImage.extent.width / 2, ciImage.extent.height / 2)
        affineTransform = CGAffineTransformRotate(affineTransform, CGFloat(-1 * M_PI_2))
        affineTransform = CGAffineTransformTranslate(affineTransform, -ciImage.extent.width / 2, -ciImage.extent.height / 2)
        
        let transformFilter = CIFilter(
            name: "CIAffineTransform",
            withInputParameters: [
                kCIInputImageKey: ciImage,
                kCIInputTransformKey: NSValue(CGAffineTransform: affineTransform)
            ]
        )
        
        let transformedCIImage = transformFilter!.outputImage!
        
        let scale = UIScreen.mainScreen().scale
        let previewImageFrame = CGRectMake(0, 0, cameraView.frame.width * scale, cameraView.frame.height * scale)
        
        // Draw the transfromedCIImage sized by previewImageFrame on GLKView.
        if glContext != EAGLContext.currentContext() {
            EAGLContext.setCurrentContext(glContext)
        }
        
        glView.bindDrawable()
        ciContext.drawImage(transformedCIImage, inRect: previewImageFrame, fromRect: transformedCIImage.extent)
        glView.display()
        
    }
    
    
    // Impelemnt the delegate method
    // Interface: AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(captureOutput: AVCaptureOutput!, didDropSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        // Here we can deal with the frames have been droped.
    }
}
