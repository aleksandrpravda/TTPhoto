//
//  Copyright © 2019 aleksandrpravda. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

protocol TTPCaptureSessionManagerProtocol {
    var weaklayer: AVCaptureVideoPreviewLayer? {get set}
    func start()
    func stop()
    func capturePhoto(orientation: AVCaptureVideoOrientation)
}

protocol TTPhotoLibraryProtocol {
    func fetchAssetFromCollection(from collection: PHAssetCollection?) -> [PHAsset]?
    func fetchImage(asset: PHAsset, size: CGSize, callback: @escaping (UIImage?) -> Void)
    func getCollections() -> [PHAssetCollection]
    func changeCamera()
    func focus(at point: CGPoint)
    func fetchAsset(with identifires: [String]) -> [PHAsset]
}

typealias TTPhotoProtocol = TTPCaptureSessionManagerProtocol & TTPhotoLibraryProtocol

class TTPCaptureSessionManager: NSObject, TTPhotoProtocol {
    private enum SetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    var windowOrientation: UIInterfaceOrientation {
        return UIInterfaceOrientation.portrait
    }
    
    private let session: AVCaptureSession
    @objc private dynamic var videoDeviceInput: AVCaptureDeviceInput!
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "session queue")
    private var setupResult = SetupResult.success
    private var librarySetupResult = SetupResult.success
    private var inProgressPhotoCaptureDelegates = [Int64: PhotoCaptureProcessor]()
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera], mediaType: .video, position: .unspecified)
    
    private lazy var context = CIContext()
    private var photoCapture: AVCapturePhoto?
    private var livePhotoCompanionMovieURL: URL?
    private var portraitEffectsMatteData: Data?
    private var semanticSegmentationMatteDataArray = [Data]()
    private var maxPhotoProcessingTime: CMTime?
    
    weak var weaklayer: AVCaptureVideoPreviewLayer? {
        didSet {
            weaklayer?.session = self.session
        }
    }
    
    override init() {
        self.session = AVCaptureSession()
        super.init()
        self.captureDeviceAutorisation()
        self.sessionQueue.async {
            self.configureSession()
        }
        self.sessionQueue.async {
            self.captureLibraryDeviceAutorisation()
        }
    }
    
    func getCollections() -> [PHAssetCollection] {
        if self.librarySetupResult == .notAuthorized {
            return []
        }
        let options = PHFetchOptions()
        let result = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: options)
        var collections = [PHAssetCollection]()
        result.enumerateObjects { (collection, index, _) in
            collections.append(collection)
        }
        return collections
    }
    
    func fetchAssetFromCollection(from collection: PHAssetCollection?) -> [PHAsset]? {
        if self.librarySetupResult == .notAuthorized {
            return []
        }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        if let collectionTmp = collection {
            var assets = [PHAsset]()
            let result = PHAsset.fetchAssets(in: collectionTmp, options: options)
            result.enumerateObjects { (collection, index, _) in
                assets.append(collection)
            }
            return assets
        }
        return nil
    }
    
    func fetchAsset(with identifires: [String]) -> [PHAsset] {
        if self.librarySetupResult == .notAuthorized {
            return []
        }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        var assets = [PHAsset]()
        let result = PHAsset.fetchAssets(withLocalIdentifiers: identifires, options: options)
        result.enumerateObjects { (collection, index, _) in
            assets.append(collection)
        }
        return assets
    }
    
    func fetchImage(asset: PHAsset, size: CGSize, callback: @escaping (UIImage?) -> Void) {
        if self.librarySetupResult == .notAuthorized {
            return
        }
        let option = PHImageRequestOptions()
        option.isNetworkAccessAllowed = true
        option.isSynchronous = true
        PHImageManager.default().requestImage(for: asset,
                                              targetSize: size,
                                              contentMode: .aspectFill,
                                              options: option) { (image, _) -> Void in
                                                callback(image)
        }
    }
    
    func start() {
        self.sessionQueue.async {
            switch self.setupResult {
            case .success:
                self.session.startRunning()
            case .notAuthorized:
                DispatchQueue.main.async {
//                    TODO send notification
                }
                
            case .configurationFailed:
                DispatchQueue.main.async {
                    //TODO send notification
                }
            }
        }
    }
    
    func stop() {
        self.sessionQueue.async {
            if self.setupResult == .success {
                self.session.stopRunning()
            }
        }
    }
    
    func capturePhoto(orientation: AVCaptureVideoOrientation) {
        sessionQueue.async {
            if let photoOutputConnection = self.photoOutput.connection(with: .video) {
                photoOutputConnection.videoOrientation = orientation
            }
            let photoSettings = self.photoSettings()
            let photoCaptureProcessor = PhotoCaptureProcessor(
                capturePhotoAnimation: {
                    DispatchQueue.main.async {
                        self.weaklayer?.opacity = 0
                        UIView.animate(withDuration: 0.25) {
                            self.weaklayer?.opacity = 1
                        }
                    }
                },
                completionHandler: { photoCaptureProcessor, data in
                    self.sessionQueue.async {
                        self.inProgressPhotoCaptureDelegates[photoSettings.uniqueID] = nil
                        if let data = data {
                            DispatchQueue.main.async {
                                self.saveAsset(photoData: data, settings: photoSettings)
                            }
                        }
                    }
                }
            )
            self.inProgressPhotoCaptureDelegates[photoSettings.uniqueID] = photoCaptureProcessor
            self.photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureProcessor)
        }
    }
    
    func focus(at point: CGPoint) {
        sessionQueue.async {
            let device = self.videoDeviceInput.device
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }
                
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                }
                
                device.isSubjectAreaChangeMonitoringEnabled = true
                device.unlockForConfiguration()
            } catch {
                print("TTPCaptureSessionManager::focus: \(error)")
            }
        }
    }
    
    func changeCamera() {
        self.sessionQueue.async {
            let currentVideoDevice = self.videoDeviceInput.device
            let currentPosition = currentVideoDevice.position

            let preferredPosition: AVCaptureDevice.Position
            let preferredDeviceType: AVCaptureDevice.DeviceType

            switch currentPosition {
            case .unspecified, .front:
                preferredPosition = .back
                preferredDeviceType = .builtInDualCamera
            case .back:
                preferredPosition = .front
                preferredDeviceType = .builtInTrueDepthCamera
            @unknown default:
                preferredPosition = .back
                preferredDeviceType = .builtInDualCamera
            }
            let devices = self.videoDeviceDiscoverySession.devices
            var newVideoDevice: AVCaptureDevice? = nil

            if let device = devices.first(where: { $0.position == preferredPosition && $0.deviceType == preferredDeviceType }) {
                newVideoDevice = device
            } else if let device = devices.first(where: { $0.position == preferredPosition }) {
                newVideoDevice = device
            }

            if let videoDevice = newVideoDevice {
                do {
                    let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)

                    self.session.beginConfiguration()
                    self.session.removeInput(self.videoDeviceInput)

                    if self.session.canAddInput(videoDeviceInput) {
                        self.session.addInput(videoDeviceInput)
                        self.videoDeviceInput = videoDeviceInput
                    } else {
                        self.session.addInput(self.videoDeviceInput)
                    }
                    self.photoOutput.isLivePhotoCaptureEnabled = self.photoOutput.isLivePhotoCaptureSupported
                    self.photoOutput.isDepthDataDeliveryEnabled = self.photoOutput.isDepthDataDeliverySupported
                    self.photoOutput.isPortraitEffectsMatteDeliveryEnabled = self.photoOutput.isPortraitEffectsMatteDeliverySupported

                    self.session.commitConfiguration()
                } catch {
                    print("Error occurred while creating video device input: \(error)")
                }
            }
        }
    }
    
    private func configureSession() {
        if setupResult != .success {
            return
        }
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard let videoDeviceInput = self.defaultVideoDiviceInput() else {
            self.session.commitConfiguration()
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        if self.session.canAddInput(videoDeviceInput) {
            self.session.addInput(videoDeviceInput)
            self.videoDeviceInput = videoDeviceInput
            DispatchQueue.main.async {
                var initialVideoOrientation: AVCaptureVideoOrientation = .portrait
                if self.windowOrientation != .unknown {
                    if let videoOrientation = AVCaptureVideoOrientation(rawValue: self.windowOrientation.rawValue) {
                        initialVideoOrientation = videoOrientation
                    }
                }
                self.weaklayer?.connection?.videoOrientation = initialVideoOrientation
            }
        } else {
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        self.configurePhotoOutput()
        if session.canAddOutput(self.photoOutput) {
            self.session.addOutput(self.photoOutput)
        } else {
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        session.commitConfiguration()
    }
    
    private func captureDeviceAutorisation() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
        default:
            setupResult = .notAuthorized
        }
    }
    
    func captureLibraryDeviceAutorisation() {
        DispatchQueue.main.async {
            PHPhotoLibrary.requestAuthorization { status in
                switch status {
                case .notDetermined:
                    self.librarySetupResult = .notAuthorized
                case .denied:
                    self.librarySetupResult = .notAuthorized
                case .authorized:
                    self.librarySetupResult = .success
                default:
                    self.librarySetupResult = .notAuthorized
                }
            }
        }
    }
    
    private func photoSettings() -> AVCapturePhotoSettings{
        var photoSettings = AVCapturePhotoSettings()
        if  self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        }
        
        if self.videoDeviceInput.device.isFlashAvailable {
            photoSettings.flashMode = .auto
        }
        
        photoSettings.isHighResolutionPhotoEnabled = true
        if !photoSettings.__availablePreviewPhotoPixelFormatTypes.isEmpty {
            photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoSettings.__availablePreviewPhotoPixelFormatTypes.first!]
            photoSettings.isDepthDataDeliveryEnabled = (self.photoOutput.isDepthDataDeliveryEnabled)
            photoSettings.isPortraitEffectsMatteDeliveryEnabled = (self.photoOutput.isPortraitEffectsMatteDeliveryEnabled)
        }
        return photoSettings
    }
    
    private func defaultVideoDiviceInput() -> AVCaptureDeviceInput? {
        do {
            var defaultVideoDevice: AVCaptureDevice?
            if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
                defaultVideoDevice = dualCameraDevice
            } else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                defaultVideoDevice = backCameraDevice
            } else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                defaultVideoDevice = frontCameraDevice
            }
            guard let videoDevice = defaultVideoDevice else {
                print("Default video device is unavailable.")
                return nil
            }
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            return videoDeviceInput
        }
        catch {
            print("Cannot capture AVCaptureDeviceInput")
            return nil
        }
    }
    
    private func configurePhotoOutput() {
        self.photoOutput.isHighResolutionCaptureEnabled = true
        self.photoOutput.isDepthDataDeliveryEnabled = photoOutput.isDepthDataDeliverySupported
        self.photoOutput.isPortraitEffectsMatteDeliveryEnabled = self.photoOutput.isPortraitEffectsMatteDeliverySupported
    }
    
    private func saveAsset(photoData: Data, settings: AVCapturePhotoSettings) {
        if self.librarySetupResult == .notAuthorized {
            return
        }
        PHPhotoLibrary.shared().performChanges({
            let options = PHAssetResourceCreationOptions()
            let creationRequest = PHAssetCreationRequest.forAsset()
            options.uniformTypeIdentifier = settings.processedFileType.map { $0.rawValue }
            creationRequest.addResource(with: .photo, data: photoData, options: options)
        }, completionHandler: { _, error in
            if let error = error {
                print("Error occurred while saving photo to photo library: \(error)")
            }
        })
    }
}
