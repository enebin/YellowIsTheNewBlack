//
//  VideoSessionManager.swift
//  YellowIsTheNewBlack
//
//  Created by 프라이빗 on 2022/06/18.
//

import UIKit
import AVFoundation

class VideoSessionManager: NSObject {
    static let shared = VideoSessionManager()
    
    // Dependencies
    private let videoFileManager: VideoFileManager
    private let captureSession: AVCaptureSession
    private var device: AVCaptureDevice? = nil
    private var output: AVCaptureMovieFileOutput? = nil

    // MARK: - Public methods and vars
    
    var previewLayer: AVCaptureVideoPreviewLayer {
        AVCaptureVideoPreviewLayer(session: self.captureSession)
    }
    
    /// Set up the AV session
    ///
    /// init안에서 안 돌리고 밖에서 실행하는 이유는
    /// 에러핸들링을 `init` 외에서 해 조금이나마 용이하게 하기 위함임.
    func setupSession() throws {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            try self.setUpCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    do {
                        try self.setUpCaptureSession()
                    }
                    catch let error {
                        print(error.localizedDescription)
                    }
                }
            }
        case .denied:
            return
        case .restricted:
            return
        @unknown default:
            fatalError()
        }
    }
    
    /// 카메라를 돌리기 시작함
    func startRunningCamera() {
        self.captureSession.startRunning()
    }
    
    /// '녹화'를 시작함
    func startRecordingVideo() throws {
        guard let output = self.output else {
            throw VideoRecorderError.notConfigured
        }
        
        let filePath = videoFileManager.filePath
        output.startRecording(to: filePath, recordingDelegate: self)
    }
    
    func stopRecordingVideo() throws {
        guard let output = self.output else {
            throw VideoRecorderError.notConfigured
        }
        
        output.stopRecording()
    }
    
    // MARK: - Internal methods
    
    private func setUpCaptureSession() throws {
        guard let device = self.device else {
            throw VideoRecorderError.invalidDevice
        }
        
        captureSession.beginConfiguration()
        
        let deviceInput = try AVCaptureDeviceInput(device: device)
        if captureSession.canAddInput(deviceInput) {
            captureSession.addInput(deviceInput)
        } else {
            throw VideoRecorderError.unableToSetInput
        }
        
        let audioDevice = AVCaptureDevice.default(for: AVMediaType.audio)!
        let audioInput = try AVCaptureDeviceInput(device: audioDevice)
        if captureSession.canAddInput(audioInput) {
            captureSession.addInput(audioInput)
        } else {
            throw VideoRecorderError.unableToSetInput
        }
        
        let fileOutput = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(fileOutput) {
            self.output = fileOutput
            captureSession.addOutput(fileOutput)
        } else {
            throw VideoRecorderError.unableToSetOutput
        }
        
        captureSession.commitConfiguration()
    }
    
    /// Finds the best camera among the several cameras
    ///
    /// Only back postion is supported now
    private func findBestCamera(in position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if let device = AVCaptureDevice.default(.builtInDualCamera,
                                                for: .video,
                                                position: position) {
            return device
        } else if let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: position) {
            return device
        } else {
            return nil
        }
    }
    
    // MARK: - Init
    
    init(_ captureSession: AVCaptureSession = AVCaptureSession(),
         _ videoFileManager: VideoFileManager = VideoFileManager.default,
         quality: AVCaptureSession.Preset = .medium,
         position: AVCaptureDevice.Position = .back
    ) {
        captureSession.sessionPreset = quality
        
        self.captureSession = captureSession
        self.videoFileManager = videoFileManager
        
        super.init() // Why?
        
        let deviceFound = self.findBestCamera(in: position)
        self.device = deviceFound
    }
}

extension VideoSessionManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Error recording movie: \(error.localizedDescription), \(error)")
        } else {
            if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(outputFileURL.path) {
                // Save to the album roll
                UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.path, self, nil, nil)
                
                // Add to the local memory
                videoFileManager.addAfterEncode(at: outputFileURL)
            } else {
                print("Error while saving movie")
                return
            }
        }
    }
}
