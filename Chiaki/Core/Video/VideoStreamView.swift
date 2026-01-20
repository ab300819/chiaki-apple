// SPDX-License-Identifier: AGPL-3.0-only
//
// VideoStreamView.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// SwiftUI wrapper for Metal-based video rendering

import SwiftUI
import MetalKit
import CoreVideo
import Combine

#if os(iOS) || os(tvOS)
import UIKit
typealias NativeViewContext = UIViewRepresentableContext<VideoStreamView>
#elseif os(macOS)
import AppKit
typealias NativeViewContext = NSViewRepresentableContext<VideoStreamView>
#endif

// MARK: - Video Stream View

/// SwiftUI view for displaying video stream using Metal
struct VideoStreamView: ViewRepresentable {
    var renderer: MetalVideoRenderer?

    var displayMode: VideoDisplayMode

    var zoomFactor: Float

    var preferredFramesPerSecond: Int

    var onMTKViewCreated: ((MTKView) -> Void)?

    init(
        renderer: MetalVideoRenderer?,
        displayMode: VideoDisplayMode = .normal,
        zoomFactor: Float = 1.0,
        preferredFramesPerSecond: Int = 60,
        onMTKViewCreated: ((MTKView) -> Void)? = nil
    ) {
        self.renderer = renderer
        self.displayMode = displayMode
        self.zoomFactor = zoomFactor
        self.preferredFramesPerSecond = preferredFramesPerSecond
        self.onMTKViewCreated = onMTKViewCreated
    }

    #if os(iOS) || os(tvOS)
    func makeUIView(context: Context) -> MTKView {
        createMTKView(context: context)
    }

    func updateUIView(_ mtkView: MTKView, context: Context) {
        updateMTKView(mtkView, context: context)
    }
    #elseif os(macOS)
    func makeNSView(context: Context) -> MTKView {
        createMTKView(context: context)
    }

    func updateNSView(_ mtkView: MTKView, context: Context) {
        updateMTKView(mtkView, context: context)
    }
    #endif

    private func createMTKView(context: Context) -> MTKView {
        let mtkView = MTKView()

        // Configure Metal view
        if let device = MTLCreateSystemDefaultDevice() {
            mtkView.device = device
        }

        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = true
        mtkView.preferredFramesPerSecond = preferredFramesPerSecond
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        
        #if os(iOS) || os(tvOS)
        mtkView.contentMode = .scaleToFill
        #endif

        // Clear color (black background)
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        // Setup delegate
        if let renderer = renderer {
            mtkView.delegate = renderer
            renderer.updateViewSize(mtkView.drawableSize)
        }

        onMTKViewCreated?(mtkView)

        return mtkView
    }

    private func updateMTKView(_ mtkView: MTKView, context: Context) {
        // Update renderer reference
        if let renderer = renderer {
            mtkView.delegate = renderer
            renderer.displayMode = displayMode
            renderer.zoomFactor = zoomFactor
            renderer.updateViewSize(mtkView.drawableSize)
        }

        // Update frame rate
        mtkView.preferredFramesPerSecond = preferredFramesPerSecond
    }
}

// MARK: - Video Renderer Holder

/// Observable object that holds the video renderer for SwiftUI state management
@MainActor
final class VideoRendererHolder: ObservableObject {
    @Published private(set) var renderer: MetalVideoRenderer?

    /// Whether renderer is ready
    var isReady: Bool { renderer != nil }

    /// Initialize renderer
    func initialize() {
        guard renderer == nil else { return }
        renderer = MetalVideoRenderer()

        if renderer != nil {
            logInfo("VideoRendererHolder: Renderer initialized")
        } else {
            logError("VideoRendererHolder: Failed to initialize renderer")
        }
    }

    /// Submit a video frame
    func submitFrame(_ pixelBuffer: CVPixelBuffer) {
        renderer?.submitFrame(pixelBuffer)
    }

    /// Set display mode
    func setDisplayMode(_ mode: VideoDisplayMode) {
        renderer?.displayMode = mode
    }

    /// Set zoom factor
    func setZoomFactor(_ factor: Float) {
        renderer?.zoomFactor = factor
    }

    /// Set color adjustments
    func setColorAdjustments(brightness: Float, contrast: Float, saturation: Float) {
        renderer?.setBrightness(brightness)
        renderer?.setContrast(contrast)
        renderer?.setSaturation(saturation)
    }

    /// Get frame statistics
    var frameCount: UInt64 { renderer?.frameCount ?? 0 }
    var droppedFrameCount: UInt64 { renderer?.droppedFrameCount ?? 0 }

    /// Reset statistics
    func resetStatistics() {
        renderer?.resetStatistics()
    }

    /// Flush texture cache
    func flushTextureCache() {
        renderer?.flushTextureCache()
    }

    /// Cleanup
    func cleanup() {
        renderer?.flushTextureCache()
        renderer = nil
        logInfo("VideoRendererHolder: Cleaned up")
    }

    deinit {
        // Note: Cannot call MainActor-isolated logInfo from deinit
    }
}

// MARK: - Preview

#if DEBUG
struct VideoStreamView_Previews: PreviewProvider {
    static var previews: some View {
        VideoStreamViewPreview()
    }
}

private struct VideoStreamViewPreview: View {
    @State private var renderer: MetalVideoRenderer? = MetalVideoRenderer()

    var body: some View {
        VideoStreamView(
            renderer: renderer,
            displayMode: .normal,
            zoomFactor: 1.0
        )
        .ignoresSafeArea()
    }
}
#endif
