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
        
        // TODO(T-246): Implementation of IOSurface -> VkImage import
        
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
        // TODO(T-246): pl_gpu_flush()
    }

    func resetStatistics() {
        lock.lock()
        frameCount = 0
        droppedFrameCount = 0
        lock.unlock()
    }

    // MARK: - Rendering

    func render(to view: MTKView, descriptor: MTLRenderPassDescriptor?) {
        guard hasFrame else { return }
        
        // TODO(T-245/T-246): Implementation of pl_render_image
        // 1. pl_swapchain_start_frame
        // 2. build pl_frame from submitted IOSurface/VkImage
        // 3. pl_render_image
        // 4. pl_swapchain_swap_buffers

        lock.lock()
        frameCount += 1
        lock.unlock()
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
