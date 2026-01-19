// SPDX-License-Identifier: AGPL-3.0-only
//
// PiPManager.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Manager for Picture-in-Picture support using AVPictureInPictureVideoCallRenderer

import AVKit
import Observation
import CoreVideo

#if os(iOS)
import UIKit
#endif

@Observable
final class PiPManager: NSObject {
    #if os(iOS)
    private var pipController: AVPictureInPictureController?
    private var videoCallRenderer: AVPictureInPictureVideoCallRenderer?
    #endif
    
    var isPiPActive = false
    var isPiPSupported: Bool {
        #if os(iOS)
        return AVPictureInPictureController.isPictureInPictureSupported()
        #else
        return false
        #endif
    }
    
    #if os(iOS)
    func setup(with sourceView: UIView) {
        guard isPiPSupported else { return }
        
        let renderer = AVPictureInPictureVideoCallRenderer()
        self.videoCallRenderer = renderer
        
        let contentSource = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: sourceView,
            contentViewController: nil
        )
        
        pipController = AVPictureInPictureController(contentSource: contentSource)
        pipController?.delegate = self
        pipController?.canStartPictureInPictureAutomaticallyFromInline = true
    }
    #else
    func setup(with sourceView: Any) {}
    #endif
    
    func togglePiP() {
        #if os(iOS)
        guard let pipController = pipController else { return }
        if pipController.isPictureInPictureActive {
            pipController.stopPictureInPicture()
        } else {
            pipController.startPictureInPicture()
        }
        #endif
    }
    
    func enqueue(_ pixelBuffer: CVPixelBuffer) {
        #if os(iOS)
        videoCallRenderer?.enqueue(pixelBuffer)
        #endif
    }
}

#if os(iOS)
extension PiPManager: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPiPActive = true
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPiPActive = false
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        isPiPActive = false
    }
}
#endif
