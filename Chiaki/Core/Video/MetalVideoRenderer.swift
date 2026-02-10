// SPDX-License-Identifier: AGPL-3.0-only
//
// MetalVideoRenderer.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// High-performance Metal-based video renderer with zero-copy CVPixelBuffer support

import Foundation
import Metal
import MetalKit
import CoreVideo
import simd

// MARK: - Video Uniforms

/// Uniforms passed to Metal shaders

/// [requirement] F-025, F-028
/// [satisfies] AC-081, AC-084, AC-097, AC-098, AC-099
struct VideoUniforms {
    var transform: simd_float4x4
    var textureSizeY: simd_float2
    var textureSizeUV: simd_float2
    var brightness: Float
    var contrast: Float
    var saturation: Float
    var colorSpace: UInt32   // 0 = BT.709 (HD), 1 = BT.601 (SD), 2 = BT.2020 (HDR)
    var colorRange: UInt32   // 0 = VideoRange(Limited), 1 = FullRange
    var edrHeadroom: Float   // AC-081: EDR Headroom (1.0+)
    var tonemapMode: UInt32  // AC-084: 0 = None (EDR), 1 = ACES Filmic (SDR)
    var edrIntensity: Float        // AC-098: EDR Output intensity multiplier (default 1.0)
    var gamutMappingEnabled: UInt32 // AC-099: 0 = Disabled, 1 = Enabled (default)
    // F-041: Video filter pipeline parameters
    var upscaleFilter: UInt32      // AC-159: 0 = bilinear, 1 = bicubic Catmull-Rom
    var casStrength: Float         // AC-161: CAS sharpening strength (0.0 - 1.0)
    var debandEnabled: UInt32      // AC-163: 0 = off, 1 = on
    var debandThreshold: Float     // AC-163: deband threshold
    var debandGrain: Float         // AC-163: dither grain intensity
    var _padding1: Float = 0.0     // Ensure 16-byte alignment (Total: 144 bytes)
    var _padding2: Float = 0.0

    static var `default`: VideoUniforms {
        let filterDefaults = VideoFilterConfig.default
        return VideoUniforms(
            transform: matrix_identity_float4x4,
            textureSizeY: simd_float2(1920, 1080),
            textureSizeUV: simd_float2(960, 540),
            brightness: 1.0,
            contrast: 1.0,
            saturation: 1.0,
            colorSpace: 0,
            colorRange: 0,
            edrHeadroom: 1.0,
            tonemapMode: 0,
            edrIntensity: 1.0,
            gamutMappingEnabled: 1,
            upscaleFilter: filterDefaults.upscaleFilter,
            casStrength: filterDefaults.casStrength,
            debandEnabled: filterDefaults.debandEnabled,
            debandThreshold: filterDefaults.debandThreshold,
            debandGrain: filterDefaults.debandGrain,
            _padding1: 0.0,
            _padding2: 0.0
        )
    }
}

// MARK: - Vertex Data

/// Vertex structure for video quad
struct VideoVertex {
    var position: simd_float2
    var texCoord: simd_float2
}

// MARK: - Metal Video Renderer

/// High-performance video renderer using Metal with CVPixelBuffer zero-copy support
final class MetalVideoRenderer: NSObject, VideoRenderer, @unchecked Sendable {
    // MARK: - Properties

    /// Metal device
    private let device: MTLDevice

    /// Command queue for rendering
    private let commandQueue: MTLCommandQueue

    /// Texture cache for zero-copy CVPixelBuffer conversion
    private var textureCache: CVMetalTextureCache?

    /// Render pipeline for biplanar YUV (NV12) - SDR
    private var biplanarPipeline: MTLRenderPipelineState?

    /// Render pipeline for BGRA - SDR
    private var bgraPipeline: MTLRenderPipelineState?

    /// Render pipeline for biplanar YUV (NV12) - HDR macOS (rgba16Float)
    private var biplanarPipelineHDR: MTLRenderPipelineState?

    /// Render pipeline for BGRA - HDR macOS (rgba16Float)
    private var bgraPipelineHDR: MTLRenderPipelineState?

    /// Render pipeline for biplanar YUV (NV12) - HDR iOS/tvOS (rgb10a2Unorm)
    private var biplanarPipelineHDR10: MTLRenderPipelineState?

    /// Render pipeline for BGRA - HDR iOS/tvOS (rgb10a2Unorm)
    private var bgraPipelineHDR10: MTLRenderPipelineState?

    /// Vertex buffer for video quad
    private var vertexBuffer: MTLBuffer?

    /// Index buffer for video quad
    private var indexBuffer: MTLBuffer?

    /// Uniforms buffer
    private var uniformsBuffer: MTLBuffer?

    /// Current video uniforms
    private var uniforms = VideoUniforms.default

    /// HDR configuration
    /// [requirement] F-025, F-028
    /// [satisfies] AC-088, AC-097, AC-098, AC-099
    var hdrConfiguration: HDRConfiguration = .sdr {
        didSet {
            uniforms.colorSpace = hdrConfiguration.colorSpace.rawValue
            uniforms.colorRange = hdrConfiguration.colorRange.rawValue
            uniforms.tonemapMode = hdrConfiguration.tonemapMode.rawValue
            uniforms.edrIntensity = hdrConfiguration.edrIntensity
            uniforms.gamutMappingEnabled = hdrConfiguration.gamutMappingEnabled ? 1 : 0
            triggerRedraw()
        }
    }

    /// EDR Headroom (1.0+)
    /// [requirement] F-025
    /// [satisfies] AC-081
    var edrHeadroom: Float {
        get { uniforms.edrHeadroom }
        set {
            uniforms.edrHeadroom = max(1.0, newValue)
            triggerRedraw()
        }
    }

    /// Tone mapping mode for HDR→SDR conversion
    /// [requirement] F-025
    /// [satisfies] AC-084
    var tonemapMode: TonemapMode {
        get { TonemapMode(rawValue: uniforms.tonemapMode) ?? .passthrough }
        set {
            uniforms.tonemapMode = newValue.rawValue
            triggerRedraw()
        }
    }

    /**
     * Set EDR output intensity (0.5 - 2.0)
     * @requirement F-028
     * @satisfies AC-098
     */
    func setEDRIntensity(_ value: Float) {
        let clamped = max(0.5, min(2.0, value))
        frameLock.lock()
        uniforms.edrIntensity = clamped
        hdrConfiguration.edrIntensity = clamped
        frameLock.unlock()
        triggerRedraw()
    }

    /**
     * Set gamut mapping enabled
     * @requirement F-028
     * @satisfies AC-099
     */
    func setGamutMappingEnabled(_ enabled: Bool) {
        frameLock.lock()
        uniforms.gamutMappingEnabled = enabled ? 1 : 0
        hdrConfiguration.gamutMappingEnabled = enabled
        frameLock.unlock()
        triggerRedraw()
    }

    /// Current display mode
    var displayMode: VideoDisplayMode = .normal {
        didSet {
            updateTransform()
            triggerRedraw()
        }
    }

    /// Zoom factor (only used in zoom mode)
    var zoomFactor: Float = 1.0 {
        didSet {
            updateTransform()
            triggerRedraw()
        }
    }

    /// Video source size
    private var videoSize: CGSize = CGSize(width: 1920, height: 1080)

    /// View size
    private var viewSize: CGSize = CGSize(width: 1920, height: 1080)

    /// Current Y texture
    private var currentTextureY: MTLTexture?

    /// Current UV texture
    private var currentTextureUV: MTLTexture?

    /// Current BGRA texture
    private var currentTextureBGRA: MTLTexture?

    /// Whether current frame is biplanar
    private var isBiplanar = true

    /// Lock for thread-safe frame updates
    private let frameLock = NSLock()

    /// HDR metadata cache for jitter suppression
    /// [requirement] F-025
    /// [satisfies] AC-083
    private let hdrMetadataCache = HDRMetadataCache()

    /// Frame counter for statistics
    private(set) var frameCount: UInt64 = 0

    /// Dropped frame counter
    private(set) var droppedFrameCount: UInt64 = 0

    /// Whether a frame has been submitted and is ready for rendering
    /// [satisfies] AC-086
    var hasFrame: Bool {
        frameLock.lock()
        let result = isBiplanar ? (currentTextureY != nil && currentTextureUV != nil) : (currentTextureBGRA != nil)
        frameLock.unlock()
        return result
    }

    /// Current frame size (dimensions of the last submitted frame)
    /// [satisfies] AC-086
    var frameSize: CGSize {
        videoSize
    }

    /// Weak reference to the view for power management
    weak var mtkView: MTKView?

    /// VRR (Variable Refresh Rate) enabled flag
    var vrrEnabled: Bool = true

    /// Current target frame rate
    private var targetFPS: Int = 60

    /// Callback triggered when a frame is submitted (used by MTKViewDelegateBridge for VRR)
    var onFrameSubmitted: ((CVPixelBuffer) -> Void)?

    /// Render time callback (ms)
    /// [satisfies] AC-085
    var onRenderTimeRecorded: ((Double) -> Void)?

    /// @requirement F-017 - 能效管理与渲染优化
    /// @satisfies AC-046 - 渲染能效优化
    func updateRenderingPolicy(fps: Int? = nil) {
        frameLock.lock()
        if let newFPS = fps {
            self.targetFPS = newFPS
        }
        let currentTarget = self.targetFPS
        frameLock.unlock()

        DispatchQueue.main.async { [weak self] in
            guard let self = self, let view = self.mtkView else { return }
            
            view.preferredFramesPerSecond = currentTarget

            if ProcessInfo.processInfo.isLowPowerModeEnabled {
                view.preferredFramesPerSecond = min(currentTarget, 30)
                logDebug("🔋 VRR: Low Power Mode active, capping to 30fps")
            }
            
            logInfo("🔋 VRR: Updated rendering policy to \(view.preferredFramesPerSecond)fps (Target: \(currentTarget))")
        }
    }

    // MARK: - Redraw Trigger

    /// Notify that the view needs to be redrawn
    private func triggerRedraw() {
        guard let view = mtkView else { return }
        let redraw = {
            #if os(macOS)
            view.needsDisplay = true
            #else
            view.setNeedsDisplay()
            #endif
        }
        if Thread.isMainThread {
            redraw()
        } else {
            DispatchQueue.main.async(execute: redraw)
        }
    }

    // MARK: - Initialization

    init?(device: MTLDevice? = nil) {
        guard let metalDevice = device ?? MTLCreateSystemDefaultDevice() else {
            logError("Metal is not supported on this device")
            return nil
        }

        self.device = metalDevice

        guard let queue = metalDevice.makeCommandQueue() else {
            logError("Failed to create Metal command queue")
            return nil
        }
        self.commandQueue = queue

        super.init()

        // Create texture cache for zero-copy CVPixelBuffer conversion
        var cache: CVMetalTextureCache?
        let status = CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            nil,
            metalDevice,
            nil,
            &cache
        )

        guard status == kCVReturnSuccess, let textureCache = cache else {
            logError("Failed to create CVMetalTextureCache: \(status)")
            return nil
        }
        self.textureCache = textureCache

        // Setup rendering resources
        guard setupPipelines() && setupBuffers() else {
            return nil
        }

        logInfo("MetalVideoRenderer initialized successfully")
    }

    deinit {
        textureCache = nil
        logInfo("MetalVideoRenderer deinitialized")
    }

    // MARK: - Setup

    private func setupPipelines() -> Bool {
        // Try to load from default library first, fall back to runtime compilation
        let library: MTLLibrary
        if let defaultLibrary = device.makeDefaultLibrary() {
            library = defaultLibrary
            logInfo("Loaded Metal shaders from default library")
        } else {
            // Compile shaders from source at runtime
            logInfo("Compiling Metal shaders from source...")
            do {
                library = try device.makeLibrary(source: Self.shaderSource, options: nil)
                logInfo("Metal shaders compiled successfully")
            } catch {
                logError("Failed to compile Metal shaders: \(error)")
                return false
            }
        }

        // Vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<simd_float2>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<VideoVertex>.stride

        // Common pipeline descriptor setup
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        // Get shader functions
        guard let vertexFunction = library.makeFunction(name: "videoVertexShader") else {
            logError("Failed to load vertex shader")
            return false
        }
        pipelineDescriptor.vertexFunction = vertexFunction

        guard let biplanarFragment = library.makeFunction(name: "videoBiplanarFragmentShader"),
              let bgraFragment = library.makeFunction(name: "videoBGRAFragmentShader") else {
            logError("Failed to load fragment shaders")
            return false
        }

        // Create SDR pipelines (bgra8Unorm)
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        pipelineDescriptor.fragmentFunction = biplanarFragment
        pipelineDescriptor.label = "Biplanar Video Pipeline (SDR)"
        do {
            biplanarPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            logError("Failed to create biplanar SDR pipeline: \(error)")
            return false
        }

        pipelineDescriptor.fragmentFunction = bgraFragment
        pipelineDescriptor.label = "BGRA Video Pipeline (SDR)"
        do {
            bgraPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            logError("Failed to create BGRA SDR pipeline: \(error)")
            return false
        }

        // Create HDR pipelines for macOS (rgba16Float for EDR)
        pipelineDescriptor.colorAttachments[0].pixelFormat = .rgba16Float

        pipelineDescriptor.fragmentFunction = biplanarFragment
        pipelineDescriptor.label = "Biplanar Video Pipeline (HDR-Float)"
        do {
            biplanarPipelineHDR = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            logError("Failed to create biplanar HDR pipeline: \(error)")
            return false
        }

        pipelineDescriptor.fragmentFunction = bgraFragment
        pipelineDescriptor.label = "BGRA Video Pipeline (HDR-Float)"
        do {
            bgraPipelineHDR = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            logError("Failed to create BGRA HDR pipeline: \(error)")
            return false
        }

        // Create HDR10 pipelines for iOS/tvOS (rgb10a2Unorm)
        pipelineDescriptor.colorAttachments[0].pixelFormat = .rgb10a2Unorm

        pipelineDescriptor.fragmentFunction = biplanarFragment
        pipelineDescriptor.label = "Biplanar Video Pipeline (HDR10)"
        do {
            biplanarPipelineHDR10 = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            logError("Failed to create biplanar HDR10 pipeline: \(error)")
            return false
        }

        pipelineDescriptor.fragmentFunction = bgraFragment
        pipelineDescriptor.label = "BGRA Video Pipeline (HDR10)"
        do {
            bgraPipelineHDR10 = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            logError("Failed to create BGRA HDR10 pipeline: \(error)")
            return false
        }

        logInfo("MetalVideoRenderer: Created SDR, HDR, and HDR10 render pipelines")
        return true
    }

    private func setupBuffers() -> Bool {
        // Full-screen quad vertices (position and texture coordinates)
        let vertices: [VideoVertex] = [
            VideoVertex(position: simd_float2(-1, -1), texCoord: simd_float2(0, 1)),  // Bottom-left
            VideoVertex(position: simd_float2(1, -1), texCoord: simd_float2(1, 1)),   // Bottom-right
            VideoVertex(position: simd_float2(1, 1), texCoord: simd_float2(1, 0)),    // Top-right
            VideoVertex(position: simd_float2(-1, 1), texCoord: simd_float2(0, 0))    // Top-left
        ]

        guard let vBuffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<VideoVertex>.stride * vertices.count,
            options: .storageModeShared
        ) else {
            logError("Failed to create vertex buffer")
            return false
        }
        vertexBuffer = vBuffer
        vBuffer.label = "Video Vertex Buffer"

        // Index buffer for two triangles
        let indices: [UInt16] = [0, 1, 2, 0, 2, 3]

        guard let iBuffer = device.makeBuffer(
            bytes: indices,
            length: MemoryLayout<UInt16>.stride * indices.count,
            options: .storageModeShared
        ) else {
            logError("Failed to create index buffer")
            return false
        }
        indexBuffer = iBuffer
        iBuffer.label = "Video Index Buffer"

        // Uniforms buffer
        guard let uBuffer = device.makeBuffer(
            length: MemoryLayout<VideoUniforms>.stride,
            options: .storageModeShared
        ) else {
            logError("Failed to create uniforms buffer")
            return false
        }
        uniformsBuffer = uBuffer
        uBuffer.label = "Video Uniforms Buffer"

        return true
    }

    // MARK: - Frame Handling

    /// Submit a new video frame for rendering (zero-copy from CVPixelBuffer)
    func submitFrame(_ pixelBuffer: CVPixelBuffer) {
        frameLock.lock()
        defer { frameLock.unlock() }

        guard let textureCache = textureCache else {
            logWarning("Texture cache not available")
            droppedFrameCount += 1
            return
        }

        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        videoSize = CGSize(width: width, height: height)

        // 1. Detect HDR from pixel format
        let isHDRFrame = (pixelFormat == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange)
        
        // 2. Apply jitter suppression
        // [verifies] AC-083
        let confirmedHDR = hdrMetadataCache.update(isHDRFrame: isHDRFrame)
        
        // 3. Automatically switch configuration if changed
        if confirmedHDR != hdrConfiguration.isHDR {
            hdrConfiguration = confirmedHDR ? .hdr : .sdr
            logInfo("🎬 HDR: Automatic mode switch -> \(confirmedHDR ? "HDR" : "SDR") (Jitter Suppressed)")
        }

        switch pixelFormat {
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            // Biplanar NV12 format (common from VideoToolbox)
            isBiplanar = true
            uniforms.colorSpace = 0 // BT.709 (HD)
            uniforms.colorRange = 0 // Limited range
            if frameCount == 0 {
                logInfo("🎬 SDR: Receiving 8-bit NV12 frames (colorSpace=BT.709)")
            }
            createBiplanarTextures(from: pixelBuffer, cache: textureCache, is10Bit: false)

        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
            // Biplanar NV12 full range
            isBiplanar = true
            uniforms.colorSpace = 0 // BT.709 (HD)
            uniforms.colorRange = 1 // Full range
            createBiplanarTextures(from: pixelBuffer, cache: textureCache, is10Bit: false)

        case kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange:
            // Biplanar P010 format (10-bit HDR from VideoToolbox)
            isBiplanar = true
            uniforms.colorSpace = 2 // BT.2020 (HDR)
            uniforms.colorRange = 0 // Limited range (HDR uses limited range)
            if frameCount == 0 {
                logInfo("🎬 HDR: Receiving 10-bit P010 frames (colorSpace=BT.2020)")
            }
            createBiplanarTextures(from: pixelBuffer, cache: textureCache, is10Bit: true)

        case kCVPixelFormatType_32BGRA:
            // BGRA format
            isBiplanar = false
            uniforms.colorSpace = 0 // BT.709 (HD)
            uniforms.colorRange = 1 // Full range for RGB textures
            createBGRATexture(from: pixelBuffer, cache: textureCache)

        default:
            logWarning("Unsupported pixel format: \(pixelFormat)")
            droppedFrameCount += 1
            return
        }

        frameCount += 1
        updateTransform()

        // Notify bridge that a new frame is available (for VRR handling)
        onFrameSubmitted?(pixelBuffer)

        // Request redraw
        triggerRedraw()
    }

    private func createBiplanarTextures(from pixelBuffer: CVPixelBuffer, cache: CVMetalTextureCache, is10Bit: Bool) {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        // Select texture format based on bit depth
        // 10-bit P010: Y is 16-bit (r16Unorm), UV is 16-bit per channel (rg16Unorm)
        // 8-bit NV12: Y is 8-bit (r8Unorm), UV is 8-bit per channel (rg8Unorm)
        let yFormat: MTLPixelFormat = is10Bit ? .r16Unorm : .r8Unorm
        let uvFormat: MTLPixelFormat = is10Bit ? .rg16Unorm : .rg8Unorm

        // Y plane (full resolution)
        var textureY: CVMetalTexture?
        var status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            cache,
            pixelBuffer,
            nil,
            yFormat,
            width,
            height,
            0,  // Y plane index
            &textureY
        )

        guard status == kCVReturnSuccess, let cvTextureY = textureY else {
            logWarning("Failed to create Y texture: \(status)")
            return
        }
        currentTextureY = CVMetalTextureGetTexture(cvTextureY)

        // UV plane (half resolution)
        var textureUV: CVMetalTexture?
        status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            cache,
            pixelBuffer,
            nil,
            uvFormat,
            width / 2,
            height / 2,
            1,  // UV plane index
            &textureUV
        )

        guard status == kCVReturnSuccess, let cvTextureUV = textureUV else {
            logWarning("Failed to create UV texture: \(status)")
            return
        }
        currentTextureUV = CVMetalTextureGetTexture(cvTextureUV)

        // Update uniforms
        uniforms.textureSizeY = simd_float2(Float(width), Float(height))
        uniforms.textureSizeUV = simd_float2(Float(width / 2), Float(height / 2))
    }

    private func createBGRATexture(from pixelBuffer: CVPixelBuffer, cache: CVMetalTextureCache) {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        var texture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            cache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &texture
        )

        guard status == kCVReturnSuccess, let cvTexture = texture else {
            logWarning("Failed to create BGRA texture: \(status)")
            return
        }
        currentTextureBGRA = CVMetalTextureGetTexture(cvTexture)

        uniforms.textureSizeY = simd_float2(Float(width), Float(height))
    }

    // MARK: - Rendering

    /// Render the current frame to a view (protocol conformance)
    /// - Parameters:
    ///   - view: The MTKView to render to
    ///   - descriptor: Optional render pass descriptor (uses view's current if nil)
    /// [satisfies] AC-086
    func render(to view: MTKView, descriptor: MTLRenderPassDescriptor?) {
        guard let drawable = view.currentDrawable else { return }
        let passDescriptor = descriptor ?? view.currentRenderPassDescriptor
        guard let renderPassDescriptor = passDescriptor else { return }
        render(to: drawable, renderPassDescriptor: renderPassDescriptor)
    }

    /// Render the current frame to a drawable (internal implementation)
    private func render(to drawable: CAMetalDrawable, renderPassDescriptor: MTLRenderPassDescriptor) {
        frameLock.lock()
        let hasFrame = isBiplanar ? (currentTextureY != nil && currentTextureUV != nil) : (currentTextureBGRA != nil)
        let biplanar = isBiplanar
        let textureY = currentTextureY
        let textureUV = currentTextureUV
        let textureBGRA = currentTextureBGRA
        frameLock.unlock()

        guard hasFrame else {
            // No frame yet, clear to black
            renderClear(to: drawable, renderPassDescriptor: renderPassDescriptor)
            return
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        commandBuffer.label = "Video Render Command Buffer"

        // [satisfies] AC-085
        let renderStartTime = CACurrentMediaTime()
        commandBuffer.addCompletedHandler { [weak self] _ in
            let durationMs = (CACurrentMediaTime() - renderStartTime) * 1000.0
            self?.onRenderTimeRecorded?(durationMs)
        }

        // Update uniforms
        if let uniformsBuffer = uniformsBuffer {
            memcpy(uniformsBuffer.contents(), &uniforms, MemoryLayout<VideoUniforms>.stride)
        }

        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        renderEncoder.label = "Video Render Encoder"

        // Select pipeline based on drawable pixel format and input type
        let drawableFormat = drawable.texture.pixelFormat
        let pipeline: MTLRenderPipelineState?
        if biplanar {
            switch drawableFormat {
            case .rgba16Float:
                pipeline = biplanarPipelineHDR
            case .rgb10a2Unorm:
                pipeline = biplanarPipelineHDR10
            default:
                pipeline = biplanarPipeline
            }
            renderEncoder.setFragmentTexture(textureY, index: 0)
            renderEncoder.setFragmentTexture(textureUV, index: 1)
        } else {
            switch drawableFormat {
            case .rgba16Float:
                pipeline = bgraPipelineHDR
            case .rgb10a2Unorm:
                pipeline = bgraPipelineHDR10
            default:
                pipeline = bgraPipeline
            }
            renderEncoder.setFragmentTexture(textureBGRA, index: 0)
        }

        guard let activePipeline = pipeline else {
            renderEncoder.endEncoding()
            return
        }

        renderEncoder.setRenderPipelineState(activePipeline)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBuffer(uniformsBuffer, offset: 0, index: 1)

        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: indexBuffer!,
            indexBufferOffset: 0
        )

        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func renderClear(to drawable: CAMetalDrawable, renderPassDescriptor: MTLRenderPassDescriptor) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - Transform Calculation

    /// Update view size (call when view resizes)
    func updateViewSize(_ size: CGSize) {
        viewSize = size
        updateTransform()
        triggerRedraw()
    }

    private func updateTransform() {
        let videoAspect = Float(videoSize.width / videoSize.height)
        let viewAspect = Float(viewSize.width / viewSize.height)

        var scaleX: Float = 1.0
        var scaleY: Float = 1.0

        switch displayMode {
        case .normal:
            // Letterbox/pillarbox to maintain aspect ratio
            if videoAspect > viewAspect {
                // Video is wider, pillarbox (black bars top/bottom)
                scaleY = viewAspect / videoAspect
            } else {
                // Video is taller, letterbox (black bars left/right)
                scaleX = videoAspect / viewAspect
            }

        case .stretch:
            // Fill entire view, ignore aspect ratio
            scaleX = 1.0
            scaleY = 1.0

        case .zoom:
            // Fill entire view, crop edges to maintain aspect ratio
            if videoAspect > viewAspect {
                scaleX = videoAspect / viewAspect * zoomFactor
                scaleY = zoomFactor
            } else {
                scaleX = zoomFactor
                scaleY = viewAspect / videoAspect * zoomFactor
            }
        }

        uniforms.transform = simd_float4x4(diagonal: simd_float4(scaleX, scaleY, 1.0, 1.0))
    }

    // MARK: - Color Adjustment

    /// Set brightness (0.0 - 2.0, default 1.0)
    func setBrightness(_ value: Float) {
        uniforms.brightness = max(0.0, min(2.0, value))
    }

    /// Set contrast (0.0 - 2.0, default 1.0)
    func setContrast(_ value: Float) {
        uniforms.contrast = max(0.0, min(2.0, value))
    }

    /// Set saturation (0.0 - 2.0, default 1.0)
    func setSaturation(_ value: Float) {
        uniforms.saturation = max(0.0, min(2.0, value))
    }

    /// Set color space (0 = BT.709, 1 = BT.601, 2 = BT.2020)
    func setColorSpace(_ value: UInt32) {
        uniforms.colorSpace = min(value, 2)
    }

    // MARK: - Filter Configuration

    /// Current filter configuration
    private(set) var filterConfig: VideoFilterConfig = .default

    /// Apply a video filter configuration (bicubic, CAS, deband parameters)
    /// @requirement F-041 - Metal 原生高质量视频滤波管线
    func setFilterConfig(_ config: VideoFilterConfig) {
        frameLock.lock()
        filterConfig = config
        uniforms.upscaleFilter = config.upscaleFilter
        uniforms.casStrength = config.casStrength
        uniforms.debandEnabled = config.debandEnabled
        uniforms.debandThreshold = config.debandThreshold
        uniforms.debandGrain = config.debandGrain
        frameLock.unlock()
        triggerRedraw()
    }

    // MARK: - Statistics

    /// Reset frame statistics
    func resetStatistics() {
        frameLock.lock()
        frameCount = 0
        droppedFrameCount = 0
        frameLock.unlock()
    }

    /// Flush texture cache (call periodically to free memory)
    func flushTextureCache() {
        if let cache = textureCache {
            CVMetalTextureCacheFlush(cache, 0)
        }
    }

    // MARK: - Shader Source (Runtime Compilation Fallback)

    /// Metal shader source for runtime compilation when default library is unavailable
    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float2 position [[attribute(0)]];
        float2 texCoord [[attribute(1)]];
    };

    struct VertexOut {
        float4 position [[position]];
        float2 texCoord;
    };

    struct VideoUniforms {
        float4x4 transform;
        float2 textureSizeY;
        float2 textureSizeUV;
        float brightness;
        float contrast;
        float saturation;
        uint colorSpace;  // 0 = BT.709 (HD), 1 = BT.601 (SD), 2 = BT.2020 (HDR)
        uint colorRange;  // 0 = VideoRange(Limited), 1 = FullRange
        float edrHeadroom; // AC-081: EDR Headroom (1.0+)
        uint tonemapMode;  // AC-084: 0 = None (EDR), 1 = ACES Filmic (SDR)
        float edrIntensity;        // AC-098: EDR Output intensity multiplier
        uint gamutMappingEnabled;  // AC-099: 0 = Disabled, 1 = Enabled
        // F-041: Video filter pipeline parameters
        uint upscaleFilter;        // AC-159: 0 = bilinear, 1 = bicubic
        float casStrength;         // AC-161: CAS strength (0.0 - 1.0)
        uint debandEnabled;        // AC-163: 0 = off, 1 = on
        float debandThreshold;     // AC-163: deband threshold
        float debandGrain;         // AC-163: dither grain intensity
        float _padding1;           // Align struct size to 16 bytes (144 bytes)
        float _padding2;
    };

    // Color conversion matrices (column-major)
    // Limited range: UV swing ~0.878, coefficients scaled by 1.139
    // Full range: standard coefficients, UV in [-0.5, 0.5]

    constant float3x3 kBT709Limited = float3x3(
        float3(1.0,         1.0,         1.0),
        float3(0.0,        -0.21325,     2.11240),
        float3(1.79274,    -0.53291,     0.0)
    );

    constant float3x3 kBT709Full = float3x3(
        float3(1.0,         1.0,         1.0),
        float3(0.0,        -0.18732,     1.85560),
        float3(1.57480,    -0.46812,     0.0)
    );

    constant float3x3 kBT601Limited = float3x3(
        float3(1.0,         1.0,         1.0),
        float3(0.0,        -0.39176,     2.01723),
        float3(1.59603,    -0.81297,     0.0)
    );

    constant float3x3 kBT601Full = float3x3(
        float3(1.0,         1.0,         1.0),
        float3(0.0,        -0.34414,     1.77200),
        float3(1.40200,    -0.71414,     0.0)
    );

    constant float3x3 kBT2020Limited = float3x3(
        float3(1.0,         1.0,         1.0),
        float3(0.0,        -0.18740,     2.14290),
        float3(1.67958,    -0.65046,     0.0)
    );

    constant float3x3 kBT2020Full = float3x3(
        float3(1.0,         1.0,         1.0),
        float3(0.0,        -0.16455,     1.88140),
        float3(1.47460,    -0.57135,     0.0)
    );

    // PQ (ST 2084) EOTF constants
    constant float pq_m1 = 0.1593017578125;    // 2610/16384
    constant float pq_m2 = 78.84375;           // 2523/32 * 128
    constant float pq_c1 = 0.8359375;          // 3424/4096
    constant float pq_c2 = 18.8515625;         // 2413/128
    constant float pq_c3 = 18.6875;            // 2392/128

    // PQ EOTF: Convert PQ-encoded value to linear light (0-10000 nits range, normalized)
    float3 pqEOTF(float3 pq) {
        float3 p = pow(max(pq, 0.0), 1.0 / pq_m2);
        float3 num = max(p - pq_c1, 0.0);
        float3 den = pq_c2 - pq_c3 * p;
        return pow(num / den, 1.0 / pq_m1);
    }

    // Rec.2020 to Display P3 color space conversion matrix
    // D65 white point, linear space.
    // @satisfies AC-080
    constant float3x3 kRec2020_to_P3_Matrix = float3x3(
        float3( 1.2249, -0.0420, -0.0197), // Column 0
        float3(-0.2247,  1.0419, -0.0786), // Column 1
        float3( 0.0000,  0.0000,  1.0979)  // Column 2
    );

    // Rec.2020 -> Display P3 gamut mapping
    // @satisfies AC-080
    float3 applyGamutMapping(float3 color) {
        // 1. Matrix transformation
        float3 p3 = kRec2020_to_P3_Matrix * color;
        // 2. Soft clamping (handle negative values/out-of-gamut)
        return max(p3, 0.0);
    }

    // ACES Filmic Tone Mapping fitting parameters
    // Based on Narkowicz 2015
    // @satisfies AC-084
    float3 acesTonemap(float3 x) {
        float a = 2.51;
        float b = 0.03;
        float c = 2.43;
        float d = 0.59;
        float e = 0.14;
        return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
    }

    // Convert PQ linear light (0-1 = 0-10000 nits) to Apple EDR
    // In Apple EDR, 1.0 = SDR reference white (203 nits per ITU-R BT.2408)
    // PQ linear 1.0 = 10000 nits, so scale factor = 10000 / 203 ≈ 49.26
    float3 linearToEDR(float3 linear) {
        return linear * (10000.0 / 203.0);
    }

    // Bicubic Catmull-Rom upsampling (F-041, AC-158, AC-159)
    float4 catmullRomWeights(float t) {
        float t2 = t * t;
        float t3 = t2 * t;
        float4 w;
        w.x = -0.5 * t3 + t2 - 0.5 * t;
        w.y = 1.5 * t3 - 2.5 * t2 + 1.0;
        w.z = -1.5 * t3 + 2.0 * t2 + 0.5 * t;
        w.w = 0.5 * t3 - 0.5 * t2;
        return w;
    }

    float4 sampleBicubicCatmullRom(texture2d<float> tex, sampler s, float2 uv, float2 texSize) {
        float2 texel = uv * texSize - 0.5;
        float2 f = fract(texel);
        float2 pos = floor(texel) + 0.5;
        float4 wx = catmullRomWeights(f.x);
        float4 wy = catmullRomWeights(f.y);
        float2 w01x = float2(wx.x + wx.y, wx.z + wx.w);
        float2 w01y = float2(wy.x + wy.y, wy.z + wy.w);
        float2 ox = float2(wx.y / w01x.x, wx.w / w01x.y);
        float2 oy = float2(wy.y / w01y.x, wy.w / w01y.y);
        float2 tc0 = (pos - 1.0 + float2(ox.x, oy.x)) / texSize;
        float2 tc1 = (pos + 1.0 + float2(ox.y, oy.y)) / texSize;
        float4 s00 = tex.sample(s, float2(tc0.x, tc0.y)) * w01x.x * w01y.x;
        float4 s10 = tex.sample(s, float2(tc1.x, tc0.y)) * w01x.y * w01y.x;
        float4 s01 = tex.sample(s, float2(tc0.x, tc1.y)) * w01x.x * w01y.y;
        float4 s11 = tex.sample(s, float2(tc1.x, tc1.y)) * w01x.y * w01y.y;
        return s00 + s10 + s01 + s11;
    }

    // CAS for BGRA (full RGB neighbor sampling)
    float3 contrastAdaptiveSharpening(float3 center, texture2d<float> tex, sampler s,
                                       float2 uv, float2 texSize, float strength) {
        if (strength <= 0.0) return center;
        float2 rcpSize = 1.0 / texSize;
        float3 n  = tex.sample(s, uv + float2( 0.0, -1.0) * rcpSize).rgb;
        float3 so = tex.sample(s, uv + float2( 0.0,  1.0) * rcpSize).rgb;
        float3 e  = tex.sample(s, uv + float2( 1.0,  0.0) * rcpSize).rgb;
        float3 w  = tex.sample(s, uv + float2(-1.0,  0.0) * rcpSize).rgb;
        float3 ne = tex.sample(s, uv + float2( 1.0, -1.0) * rcpSize).rgb;
        float3 nw = tex.sample(s, uv + float2(-1.0, -1.0) * rcpSize).rgb;
        float3 se = tex.sample(s, uv + float2( 1.0,  1.0) * rcpSize).rgb;
        float3 sw = tex.sample(s, uv + float2(-1.0,  1.0) * rcpSize).rgb;
        constant float3 lumaW = float3(0.2126, 0.7152, 0.0722);
        float lC  = dot(center, lumaW);
        float lN  = dot(n, lumaW); float lS  = dot(so, lumaW);
        float lE  = dot(e, lumaW); float lW  = dot(w, lumaW);
        float lNE = dot(ne, lumaW); float lNW = dot(nw, lumaW);
        float lSE = dot(se, lumaW); float lSW = dot(sw, lumaW);
        float crossMin = min(lC, min(min(lN, lS), min(lE, lW)));
        float crossMax = max(lC, max(max(lN, lS), max(lE, lW)));
        float diagMin  = min(min(lNE, lNW), min(lSE, lSW));
        float diagMax  = max(max(lNE, lNW), max(lSE, lSW));
        float mnV = min(crossMin, diagMin);
        float mxV = max(crossMax, diagMax);
        float amp = saturate(min(mnV, 1.0 - mxV) / max(mxV - mnV, 1e-5));
        amp = sqrt(amp) * strength;
        float3 total = (n + so + e + w) + 0.5 * (ne + nw + se + sw);
        float3 avg = total / 6.0;
        return max(center + (center - avg) * amp, 0.0);
    }

    // CAS for biplanar (Y-texture luma-based)
    float3 contrastAdaptiveSharpeningBiplanar(float3 center, texture2d<float> texY, sampler s,
                                               float2 uv, float2 texSize, float strength) {
        if (strength <= 0.0) return center;
        float2 rcpSize = 1.0 / texSize;
        float lC  = texY.sample(s, uv).r;
        float lN  = texY.sample(s, uv + float2( 0.0, -1.0) * rcpSize).r;
        float lS  = texY.sample(s, uv + float2( 0.0,  1.0) * rcpSize).r;
        float lE  = texY.sample(s, uv + float2( 1.0,  0.0) * rcpSize).r;
        float lW  = texY.sample(s, uv + float2(-1.0,  0.0) * rcpSize).r;
        float lNE = texY.sample(s, uv + float2( 1.0, -1.0) * rcpSize).r;
        float lNW = texY.sample(s, uv + float2(-1.0, -1.0) * rcpSize).r;
        float lSE = texY.sample(s, uv + float2( 1.0,  1.0) * rcpSize).r;
        float lSW = texY.sample(s, uv + float2(-1.0,  1.0) * rcpSize).r;
        float crossMin = min(lC, min(min(lN, lS), min(lE, lW)));
        float crossMax = max(lC, max(max(lN, lS), max(lE, lW)));
        float diagMin  = min(min(lNE, lNW), min(lSE, lSW));
        float diagMax  = max(max(lNE, lNW), max(lSE, lSW));
        float mnV = min(crossMin, diagMin);
        float mxV = max(crossMax, diagMax);
        float amp = saturate(min(mnV, 1.0 - mxV) / max(mxV - mnV, 1e-5));
        amp = sqrt(amp) * strength;
        float avgL = (lN + lS + lE + lW) * 0.25;
        float sharpFactor = (lC - avgL) * amp;
        return max(center + center * sharpFactor, 0.0);
    }

    // Debanding + Bayer dithering (F-041, AC-162, AC-163)
    constant float bayer4x4[16] = {
         0.0/16.0,  8.0/16.0,  2.0/16.0, 10.0/16.0,
        12.0/16.0,  4.0/16.0, 14.0/16.0,  6.0/16.0,
         3.0/16.0, 11.0/16.0,  1.0/16.0,  9.0/16.0,
        15.0/16.0,  7.0/16.0, 13.0/16.0,  5.0/16.0
    };
    float hashPixel(float2 p) {
        return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
    }
    float3 deband(float3 color, float2 screenPos, float2 texSize, float threshold, float grain,
                  texture2d<float> tex, sampler s, float2 uv, bool isHDR, float edrHeadroom) {
        float adjThreshold = isHDR ? threshold * edrHeadroom : threshold;
        float adjGrain = isHDR ? grain * edrHeadroom : grain;
        float2 rcpSize = 1.0 / texSize;
        float radius = 16.0;
        float angle = hashPixel(screenPos) * 6.283185;
        float2 dir = float2(cos(angle), sin(angle));
        float3 s1 = tex.sample(s, uv + dir * radius * 0.25 * rcpSize).rgb;
        float3 s2 = tex.sample(s, uv - dir * radius * 0.25 * rcpSize).rgb;
        float3 s3 = tex.sample(s, uv + dir * radius * rcpSize).rgb;
        float3 s4 = tex.sample(s, uv - dir * radius * rcpSize).rgb;
        float3 avg = (s1 + s2 + s3 + s4) * 0.25;
        float3 diff = abs(color - avg);
        float maxDiff = max(max(diff.r, diff.g), diff.b);
        float3 result = (maxDiff < adjThreshold) ? mix(color, avg, 0.5) : color;
        int bx = int(screenPos.x) & 3;
        int by = int(screenPos.y) & 3;
        float ditherValue = bayer4x4[by * 4 + bx] - 0.5;
        result += ditherValue * adjGrain;
        return result;
    }

    vertex VertexOut videoVertexShader(
        VertexIn in [[stage_in]],
        constant VideoUniforms &uniforms [[buffer(1)]]
    ) {
        VertexOut out;
        out.position = uniforms.transform * float4(in.position, 0.0, 1.0);
        out.texCoord = in.texCoord;
        return out;
    }

    fragment float4 videoBiplanarFragmentShader(
        VertexOut in [[stage_in]],
        texture2d<float> textureY [[texture(0)]],
        texture2d<float> textureUV [[texture(1)]],
        constant VideoUniforms &uniforms [[buffer(1)]]
    ) {
        constexpr sampler textureSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);

        float y;
        if (uniforms.upscaleFilter == 1u) {
            y = sampleBicubicCatmullRom(textureY, textureSampler, in.texCoord, uniforms.textureSizeY).r;
        } else {
            y = textureY.sample(textureSampler, in.texCoord).r;
        }
        float2 uv = textureUV.sample(textureSampler, in.texCoord).rg;

        if (uniforms.colorRange == 0u) {
            y = (y - 0.0625) * 1.1643835616;
        }
        uv = (uv - 0.5);

        float3x3 m;
        bool isLimited = (uniforms.colorRange == 0u);
        switch (uniforms.colorSpace) {
            case 1u:  // BT.601 (SD)
                m = isLimited ? kBT601Limited : kBT601Full;
                break;
            case 2u:  // BT.2020 (HDR)
                m = isLimited ? kBT2020Limited : kBT2020Full;
                break;
            default:  // 0 = BT.709 (HD, default)
                m = isLimited ? kBT709Limited : kBT709Full;
                break;
        }

        float3 yuv = float3(y, uv.x, uv.y);
        float3 rgb = m * yuv;

            // For HDR (BT.2020), apply PQ EOTF to convert to linear light
            if (uniforms.colorSpace == 2u) {
                // Clamp to valid PQ range before EOTF
                rgb = clamp(rgb, 0.0, 1.0);
                // Apply PQ EOTF to get linear light
                rgb = pqEOTF(rgb);
                // Gamut mapping: Rec.2020 -> P3 (AC-080)
                if (uniforms.gamutMappingEnabled == 1u) {
                    rgb = applyGamutMapping(rgb);
                }
                
                if (uniforms.tonemapMode == 1u) {
                    // ACES Tone Mapping (SDR Output)
                    rgb = acesTonemap(rgb);
                } else {
                    // HDR Output — linearToEDR maps to Apple EDR (1.0 = SDR white)
                    // Display handles values > 1.0 as HDR up to its headroom limit
                    rgb = linearToEDR(rgb);
                    rgb = rgb * uniforms.edrIntensity;
                }
                
                // Apply color adjustments in linear space
                rgb = rgb * uniforms.brightness;
                float gray = dot(rgb, float3(0.2126, 0.7152, 0.0722));
                rgb = mix(float3(gray), rgb, uniforms.saturation);
                rgb = contrastAdaptiveSharpeningBiplanar(rgb, textureY, textureSampler,
                    in.texCoord, uniforms.textureSizeY, uniforms.casStrength);
                if (uniforms.debandEnabled == 1u) {
                    rgb = deband(rgb, in.position.xy, uniforms.textureSizeY,
                        uniforms.debandThreshold, uniforms.debandGrain,
                        textureY, textureSampler, in.texCoord, true, uniforms.edrHeadroom);
                }
                rgb = max(rgb, 0.0);
            } else {
            // SDR: apply adjustments in gamma space
            rgb = (rgb - 0.5) * uniforms.contrast + 0.5;
            rgb = rgb * uniforms.brightness;
            float gray = dot(rgb, float3(0.2126, 0.7152, 0.0722));
            rgb = mix(float3(gray), rgb, uniforms.saturation);
            rgb = contrastAdaptiveSharpeningBiplanar(rgb, textureY, textureSampler,
                in.texCoord, uniforms.textureSizeY, uniforms.casStrength);
            if (uniforms.debandEnabled == 1u) {
                rgb = deband(rgb, in.position.xy, uniforms.textureSizeY,
                    uniforms.debandThreshold, uniforms.debandGrain,
                    textureY, textureSampler, in.texCoord, false, 1.0);
            }
            rgb = clamp(rgb, 0.0, 1.0);
        }

        return float4(rgb, 1.0);
    }

    fragment float4 videoBGRAFragmentShader(
        VertexOut in [[stage_in]],
        texture2d<float> texture [[texture(0)]],
        constant VideoUniforms &uniforms [[buffer(1)]]
    ) {
        constexpr sampler textureSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);

        float4 color;
        if (uniforms.upscaleFilter == 1u) {
            color = sampleBicubicCatmullRom(texture, textureSampler, in.texCoord, uniforms.textureSizeY);
        } else {
            color = texture.sample(textureSampler, in.texCoord);
        }
        float3 rgb = color.rgb;

        // For HDR (BT.2020), apply PQ EOTF to convert to linear light
        if (uniforms.colorSpace == 2u) {
            rgb = clamp(rgb, 0.0, 1.0);
            rgb = pqEOTF(rgb);
            // Gamut mapping: Rec.2020 -> P3 (AC-080)
            if (uniforms.gamutMappingEnabled == 1u) {
                rgb = applyGamutMapping(rgb);
            }

            if (uniforms.tonemapMode == 1u) {
                // ACES Tone Mapping (SDR Output)
                rgb = acesTonemap(rgb);
            } else {
                // HDR Output (EDR Scaling)
                rgb = linearToEDR(rgb);
                rgb = rgb * uniforms.edrHeadroom * uniforms.edrIntensity;
            }

            // Apply color adjustments in linear space
            rgb = rgb * uniforms.brightness;
            float gray = dot(rgb, float3(0.2126, 0.7152, 0.0722));
            rgb = mix(float3(gray), rgb, uniforms.saturation);
            rgb = contrastAdaptiveSharpening(rgb, texture, textureSampler,
                in.texCoord, uniforms.textureSizeY, uniforms.casStrength);
            if (uniforms.debandEnabled == 1u) {
                rgb = deband(rgb, in.position.xy, uniforms.textureSizeY,
                    uniforms.debandThreshold, uniforms.debandGrain,
                    texture, textureSampler, in.texCoord, true, uniforms.edrHeadroom);
            }
            rgb = max(rgb, 0.0);
        } else {
            rgb = (rgb - 0.5) * uniforms.contrast + 0.5;
            rgb = rgb * uniforms.brightness;
            float gray = dot(rgb, float3(0.2126, 0.7152, 0.0722));
            rgb = mix(float3(gray), rgb, uniforms.saturation);
            rgb = contrastAdaptiveSharpening(rgb, texture, textureSampler,
                in.texCoord, uniforms.textureSizeY, uniforms.casStrength);
            if (uniforms.debandEnabled == 1u) {
                rgb = deband(rgb, in.position.xy, uniforms.textureSizeY,
                    uniforms.debandThreshold, uniforms.debandGrain,
                    texture, textureSampler, in.texCoord, false, 1.0);
            }
            rgb = clamp(rgb, 0.0, 1.0);
        }

        return float4(rgb, color.a);
    }
    """
}

// Note: MTKViewDelegate is now implemented by MTKViewDelegateBridge in VideoStreamView.swift
// This allows VideoRenderer protocol to remain independent of Metal framework details
