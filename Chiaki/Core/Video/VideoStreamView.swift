// SPDX-License-Identifier: AGPL-3.0-only
//
// VideoStreamView.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// SwiftUI wrapper for Metal-based video rendering

import SwiftUI
import MetalKit
import CoreVideo
import CoreGraphics
import Combine

#if os(iOS) || os(tvOS)
import UIKit
typealias NativeViewContext = UIViewRepresentableContext<VideoStreamView>
#elseif os(macOS)
import AppKit
typealias NativeViewContext = NSViewRepresentableContext<VideoStreamView>
#endif

// MARK: - MTKView Delegate Bridge

/// Bridge class that implements MTKViewDelegate and delegates to VideoRenderer
/// This allows VideoRenderer to not inherit MTKViewDelegate directly
/// Handles VRR (Variable Refresh Rate) power management
/// [requirement] F-026
/// [satisfies] AC-087
final class MTKViewDelegateBridge: NSObject, MTKViewDelegate {
    weak var renderer: VideoRenderer?

    /// Flag to indicate if a new frame has been submitted and needs rendering
    private var needsRedraw = false

    #if os(macOS)
    /// Track last applied backing scale to detect changes
    private var lastAppliedScale: CGFloat = 0
    #endif

    /// Counter for idle frames (no new content)
    private var idleFrameCount: Int = 0

    /// Threshold for switching to paused mode (e.g., 2 seconds at 60fps)
    private let idleThreshold: Int = 120

    /// Lock for thread-safe access
    private let lock = NSLock()

    init(renderer: VideoRenderer?) {
        self.renderer = renderer
        super.init()

        // Subscribe to frame submission notifications
        if let renderer = renderer {
            renderer.onFrameSubmitted = { [weak self] _ in
                self?.markNeedsRedraw()
            }
        }
    }

    /// Mark that a new frame is ready for rendering
    func markNeedsRedraw() {
        lock.lock()
        needsRedraw = true
        lock.unlock()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Ensure contentsScale is correct before accepting the new drawable size
        #if os(macOS)
        if let window = view.window, let layer = view.layer {
            let scale = window.backingScaleFactor
            if layer.contentsScale != scale {
                layer.contentsScale = scale
                lastAppliedScale = scale
            }
        }
        #endif
        renderer?.updateViewSize(size)
    }

    func draw(in view: MTKView) {
        guard let renderer = renderer else { return }

        // Ensure Retina scale matches window backing scale (checked every frame)
        #if os(macOS)
        if let window = view.window {
            let scale = window.backingScaleFactor
            if lastAppliedScale != scale, let layer = view.layer {
                layer.contentsScale = scale
                lastAppliedScale = scale
                logInfo("VideoStreamView: Applied contentsScale \(scale), drawable: \(view.drawableSize)")
            }
        }
        #endif

        lock.lock()
        if !needsRedraw {
            idleFrameCount += 1

            // VRR: reduce frame rate when idle
            if renderer.vrrEnabled && idleFrameCount > 5 && view.preferredFramesPerSecond > 10 {
                view.preferredFramesPerSecond = 10
            }

            // Pause after extended idle period
            if idleFrameCount > idleThreshold && !view.isPaused {
                view.isPaused = true
                logDebug("🔋 VRR: Paused rendering after \(idleThreshold) idle frames")
            }
            lock.unlock()
            return
        }

        if view.isPaused {
            view.isPaused = false
            logDebug("🔋 VRR: Resumed rendering (new frame received)")
        }

        needsRedraw = false
        idleFrameCount = 0
        lock.unlock()

        guard let descriptor = view.currentRenderPassDescriptor else { return }
        renderer.render(to: view, descriptor: descriptor)
    }
}

// MARK: - Video Stream View

/// SwiftUI view for displaying video stream using Metal
struct VideoStreamView: ViewRepresentable {
    var renderer: VideoRenderer?

    var displayMode: VideoDisplayMode

    var zoomFactor: Float

    var preferredFramesPerSecond: Int

    var isHDR: Bool

    var onMTKViewCreated: ((MTKView) -> Void)?

    /// Dynamic EDR headroom monitor
    /// [requirement] F-025
    /// [satisfies] AC-081
    @State private var headroomMonitor = EDRHeadroomMonitor()

    init(
        renderer: VideoRenderer?,
        displayMode: VideoDisplayMode = .normal,
        zoomFactor: Float = 1.0,
        preferredFramesPerSecond: Int = 60,
        isHDR: Bool = false,
        onMTKViewCreated: ((MTKView) -> Void)? = nil
    ) {
        self.renderer = renderer
        self.displayMode = displayMode
        self.zoomFactor = zoomFactor
        self.preferredFramesPerSecond = preferredFramesPerSecond
        self.isHDR = isHDR
        self.onMTKViewCreated = onMTKViewCreated
    }

    // MARK: - Coordinator

    /// Coordinator that holds the MTKViewDelegate bridge
    class Coordinator {
        var delegateBridge: MTKViewDelegateBridge?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
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

        if isHDR {
            #if os(macOS)
            mtkView.colorPixelFormat = .rgba16Float
            #else
            mtkView.colorPixelFormat = .rgb10a2Unorm
            #endif
        } else {
            mtkView.colorPixelFormat = .bgra8Unorm
        }
        
        mtkView.framebufferOnly = true
        mtkView.preferredFramesPerSecond = preferredFramesPerSecond
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = true
        
        #if os(macOS) || os(iOS) || os(tvOS)
        if isHDR, let layer = mtkView.layer as? CAMetalLayer {
            #if os(macOS)
            layer.wantsExtendedDynamicRangeContent = true
            #endif
            // Use extended linear Display P3 for HDR - widely supported on Apple platforms
            layer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
        }
        #endif

        #if os(iOS) || os(tvOS)
        mtkView.contentMode = .scaleToFill
        #endif

        // Clear color (black background)
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        // Setup delegate bridge
        if let renderer = renderer {
            renderer.mtkView = mtkView
            let bridge = MTKViewDelegateBridge(renderer: renderer)
            mtkView.delegate = bridge
            context.coordinator.delegateBridge = bridge
            renderer.updateViewSize(mtkView.drawableSize)
        }

        onMTKViewCreated?(mtkView)

        return mtkView
    }

    private func updateMTKView(_ mtkView: MTKView, context: Context) {
        // 1. Pass EDR Headroom to renderer
        // [verifies] AC-081
        if let renderer = renderer {
            renderer.edrHeadroom = headroomMonitor.currentHeadroom
        }

        // 2. Handle dynamic HDR switching for MTKView
        // [satisfies] AC-082
        let targetPixelFormat: MTLPixelFormat
        if isHDR {
            #if os(macOS)
            targetPixelFormat = .rgba16Float
            #else
            targetPixelFormat = .rgb10a2Unorm
            #endif
        } else {
            targetPixelFormat = .bgra8Unorm
        }

        if mtkView.colorPixelFormat != targetPixelFormat {
            mtkView.colorPixelFormat = targetPixelFormat
            
            #if os(macOS) || os(iOS) || os(tvOS)
            if let layer = mtkView.layer as? CAMetalLayer {
                if isHDR {
                    #if os(macOS)
                    layer.wantsExtendedDynamicRangeContent = true
                    #endif
                    layer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
                } else {
                    #if os(macOS)
                    layer.wantsExtendedDynamicRangeContent = false
                    #endif
                    layer.colorspace = nil // Default SDR
                }
            }
            #endif
        }

        // T-228: Match drawable resolution to Retina backing scale on macOS
        // CAMetalLayer.contentsScale defaults to 1.0, causing blurry output on HiDPI
        #if os(macOS)
        if let window = mtkView.window {
            let scale = window.backingScaleFactor
            if mtkView.layer?.contentsScale != scale {
                mtkView.layer?.contentsScale = scale
            }
        }
        #endif

        // 3. Update renderer properties and delegate bridge
        if let renderer = renderer {
            renderer.mtkView = mtkView
            // Update or create delegate bridge
            if let bridge = context.coordinator.delegateBridge {
                bridge.renderer = renderer
                mtkView.delegate = bridge
            } else {
                let bridge = MTKViewDelegateBridge(renderer: renderer)
                mtkView.delegate = bridge
                context.coordinator.delegateBridge = bridge
            }
            renderer.displayMode = displayMode
            renderer.zoomFactor = zoomFactor
            renderer.updateViewSize(mtkView.drawableSize)
        }

        // 4. Update frame rate
        mtkView.preferredFramesPerSecond = preferredFramesPerSecond
    }
}

// MARK: - Video Renderer Holder

/// Observable object that holds the video renderer for SwiftUI state management
@MainActor
final class VideoRendererHolder: ObservableObject {
    @Published private(set) var renderer: VideoRenderer?

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
