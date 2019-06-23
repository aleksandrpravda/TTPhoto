//
//  Copyright © 2019 aleksandrpravda. All rights reserved.
//

import AVFoundation
import Photos

class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    
    lazy var context = CIContext()
    private let completionHandler: (PhotoCaptureProcessor, Data?) -> Void
    private let willCapturePhotoAnimation: () -> Void
    private var photoData: Data?
    private var portraitEffectsMatteData: Data?
    
    init(capturePhotoAnimation: @escaping () -> Void,
         completionHandler: @escaping (PhotoCaptureProcessor, Data?) -> Void) {
        self.completionHandler = completionHandler
        self.willCapturePhotoAnimation = capturePhotoAnimation
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        willCapturePhotoAnimation()
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
        } else {
            photoData = photo.fileDataRepresentation()
        }
        if var portraitEffectsMatte = photo.portraitEffectsMatte {
            if let orientation = photo.metadata[ String(kCGImagePropertyOrientation) ] as? UInt32 {
                portraitEffectsMatte = portraitEffectsMatte.applyingExifOrientation(CGImagePropertyOrientation(rawValue: orientation)!)
            }
            let portraitEffectsMattePixelBuffer = portraitEffectsMatte.mattingImage
            let portraitEffectsMatteImage = CIImage( cvImageBuffer: portraitEffectsMattePixelBuffer, options: [ .auxiliaryPortraitEffectsMatte: true ] )
            guard let linearColorSpace = CGColorSpace(name: CGColorSpace.linearSRGB) else {
                portraitEffectsMatteData = nil
                return
            }
            portraitEffectsMatteData = context.heifRepresentation(of: portraitEffectsMatteImage, format: .RGBA8, colorSpace: linearColorSpace, options: [ CIImageRepresentationOption.portraitEffectsMatteImage: portraitEffectsMatteImage ] )
        } else {
            portraitEffectsMatteData = nil
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if error != nil {
            completionHandler(self, nil)
            return
        }
        
        guard let photoData = photoData else {
            completionHandler(self, nil)
            return
        }
        completionHandler(self, photoData)
    }
}
