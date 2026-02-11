// SPDX-License-Identifier: AGPL-3.0-only
//
//  PlaceboVideoRenderer.swift
//  Chiaki
//
//  High-performance video renderer using libplacebo with MoltenVK (Vulkan) backend.
//
//  @requirement F-042 - libplacebo 渲染后端集成
//  @satisfies AC-173, AC-176
//

import Foundation
import Metal
import MetalKit
import CoreVideo
import QuartzCore

/// High-performance video renderer using libplacebo with MoltenVK (Vulkan) backend.
///
/// [requirement] F-042
/// [satisfies] AC-173, AC-176
final class PlaceboVideoRenderer: NSObject, VideoRenderer, @unchecked Sendable {

    // MARK: - Properties

    private let context: PlaceboContext
    private let lock = NSLock()

    /// libplacebo handle pointers (managed via PlaceboContext)
    private var log: OpaquePointer?
    private var vulkan: OpaquePointer?
    private var renderer: OpaquePointer?
    private var swapchain: OpaquePointer?

    /// Current frame textures (pl_tex)
    private var currentTexY: OpaquePointer?
    private var currentTexUV: OpaquePointer?

    /// Keep CVPixelBuffer alive during rendering to ensure IOSurface validity
    private var currentPixelBuffer: CVPixelBuffer?

    // MARK: - VideoRenderer Protocol Compliance

    weak var mtkView: MTKView? {
        didSet {
            setupSwapchain()
        }
    }

    var displayMode: VideoDisplayMode = .normal {
        didSet { triggerRedraw() }
    }

    var zoomFactor: Float = 1.0 {
        didSet { triggerRedraw() }
    }

    var vrrEnabled: Bool = true

    var hdrConfiguration: HDRConfiguration = .sdr {
        didSet { triggerRedraw() }
    }

    var edrHeadroom: Float = 1.0 {
        didSet { triggerRedraw() }
    }

    private(set) var filterConfig: VideoFilterConfig = .default

    private(set) var frameSize: CGSize = .zero
    private(set) var hasFrame: Bool = false

    private(set) var frameCount: UInt64 = 0
    private(set) var droppedFrameCount: UInt64 = 0

    var onFrameSubmitted: ((CVPixelBuffer) -> Void)?
    var onRenderTimeRecorded: ((Double) -> Void)?

    // MARK: - Initialization

    init?(context: PlaceboContext? = nil) {
        guard let ctx = context ?? PlaceboContext() else {
            return nil
        }
        self.context = ctx

        // Initialize libplacebo core objects
        guard let log = ctx.createLog(),
              let vulkan = ctx.createVulkanDevice(),
              let renderer = ctx.createRenderer() else {
            return nil
        }

        self.log = log
        self.vulkan = vulkan
        self.renderer = renderer

        super.init()
        logInfo("[placebo] core initialized successfully")
    }

    deinit {
        if let tex = currentTexY { context.destroyTexture(tex) }
        if let tex = currentTexUV { context.destroyTexture(tex) }
        // PlaceboContext.deinit → ChiakiPlaceboContextDestroy cascades
        // renderer → vulkan → log teardown in correct order.
        logInfo("[placebo] core deinitialized")
    }

    // MARK: - Frame Input

    func submitFrame(_ pixelBuffer: CVPixelBuffer) {
        lock.lock()
        defer { lock.unlock() }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        frameSize = CGSize(width: width, height: height)
        hasFrame = true
        
        guard let surface = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue() else {
            return
        }
        
        let surfacePtr = Unmanaged.passUnretained(surface).toOpaque()
        
        // Release previous textures before wrapping new ones
        if let oldTex = currentTexY { context.destroyTexture(oldTex) }
        if let oldTex = currentTexUV { context.destroyTexture(oldTex) }

        currentTexY = context.wrapIOSurface(surfacePtr, plane: 0)

        if CVPixelBufferGetPlaneCount(pixelBuffer) > 1 {
            currentTexUV = context.wrapIOSurface(surfacePtr, plane: 1)
        } else {
            currentTexUV = nil
        }
        
        currentPixelBuffer = pixelBuffer
        
        onFrameSubmitted?(pixelBuffer)
        triggerRedraw()
    }

    // MARK: - Filter & Color Adjustments

    func setFilterConfig(_ config: VideoFilterConfig) {
        lock.lock()
        filterConfig = config
        lock.unlock()
        // TODO(T-247): Map config to pl_render_params
        triggerRedraw()
    }

    func setBrightness(_ value: Float) {
        // TODO(T-247): Map to pl_color_adjustment
    }

    func setContrast(_ value: Float) {
        // TODO(T-247): Map to pl_color_adjustment
    }

    func setSaturation(_ value: Float) {
        // TODO(T-247): Map to pl_color_adjustment
    }

    func setColorSpace(_ value: UInt32) {
        // TODO(T-247): Map to pl_color_space
    }

    // MARK: - Lifecycle & View Integration

    func updateRenderingPolicy(fps: Int?) {
        guard let view = mtkView, let targetFPS = fps else { return }
        DispatchQueue.main.async {
            view.preferredFramesPerSecond = targetFPS
        }
    }

    func updateViewSize(_ size: CGSize) {
        // pl_swapchain usually handles resize via surface queries
        triggerRedraw()
    }

    func flushTextureCache() {
        // TODO(T-247): pl_gpu_flush()
    }

    func resetStatistics() {
        lock.lock()
        frameCount = 0
        droppedFrameCount = 0
        lock.unlock()
    }

    // MARK: - Rendering

    func render(to view: MTKView, descriptor: MTLRenderPassDescriptor?) {
        guard hasFrame, let texY = currentTexY else { return }
        
        let width = Int(frameSize.width)
        let height = Int(frameSize.height)
        let isHDR = hdrConfiguration.isHDR
        
        #if os(macOS)
        guard let viewLayer = view.layer else { return }
        let layerPtr = Unmanaged.passUnretained(viewLayer).toOpaque()
        #else
        let layerPtr = Unmanaged.passUnretained(view.layer).toOpaque()
        #endif

        let success = context.renderFrame(
            targetSurface: layerPtr,
            srcTexY: texY,
            srcTexUV: currentTexUV,
            width: width,
            height: height,
            isHDR: isHDR
        )

        if success {
            lock.lock()
            frameCount += 1
            lock.unlock()
        } else {
            lock.lock()
            droppedFrameCount += 1
            lock.unlock()
        }
    }

    // MARK: - Private Helpers

    private func setupSwapchain() {
        guard let _ = mtkView else {
            // TODO(T-245): destroy swapchain
            return
        }
        // TODO(T-245): create pl_swapchain from CAMetalLayer (MoltenVK VkSurfaceKHR)
    }

    private func triggerRedraw() {
        guard let view = mtkView else { return }
        DispatchQueue.main.async {
            #if os(macOS)
            view.needsDisplay = true
            #else
            view.setNeedsDisplay()
            #endif
        }
    }
}
