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

// MARK: - Video Display Mode

/// Video display modes matching chiaki-ng GUI options
enum VideoDisplayMode: Int, CaseIterable {
    case normal = 0    // Maintain aspect ratio, letterbox/pillarbox
    case stretch = 1   // Stretch to fill screen
    case zoom = 2      // Zoom to fill, crop edges

    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .stretch: return "Stretch"
        case .zoom: return "Zoom"
        }
    }
}

// MARK: - Video Uniforms

/// Uniforms passed to Metal shaders
struct VideoUniforms {
    var transform: simd_float4x4
    var textureSizeY: simd_float2
    var textureSizeUV: simd_float2
    var brightness: Float
    var contrast: Float
    var saturation: Float
    var colorSpace: UInt32   // 0 = BT.709 (HD), 1 = BT.601 (SD), 2 = BT.2020 (HDR)
    var colorRange: UInt32   // 0 = VideoRange(Limited), 1 = FullRange

    static var `default`: VideoUniforms {
        VideoUniforms(
            transform: matrix_identity_float4x4,
            textureSizeY: simd_float2(1920, 1080),
            textureSizeUV: simd_float2(960, 540),
            brightness: 1.0,
            contrast: 1.0,
            saturation: 1.0,
            colorSpace: 0,
            colorRange: 0
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
final class MetalVideoRenderer: NSObject {
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

    /// Frame counter for statistics
    private(set) var frameCount: UInt64 = 0

    /// Dropped frame counter
    private(set) var droppedFrameCount: UInt64 = 0

    /// Weak reference to the view for power management
    weak var mtkView: MTKView?

    /// Flag to indicate if a new frame has been submitted and needs rendering
    private var needsRedraw = false

    /// Counter for idle frames (no new content)
    private var idleFrameCount: Int = 0

    /// Threshold for switching to paused mode (e.g., 2 seconds at 60fps)
    private let idleThreshold: Int = 120

    var vrrEnabled: Bool = true

    /// Current target frame rate
    private var targetFPS: Int = 60

    var onFrameSubmitted: ((CVPixelBuffer) -> Void)?

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
            
            #if (os(iOS) || os(tvOS)) && !targetEnvironment(simulator)
            if #available(iOS 15.0, tvOS 15.0, *) {
                if let metalLayer = view.layer as? CAMetalLayer {
                    let range = CAFrameRateRange(minimum: 10, maximum: Float(currentTarget), preferred: Float(currentTarget))
                    metalLayer.preferredFrameRateRange = range
                }
            }
            #endif
            
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
        frameLock.lock()
        needsRedraw = true
        frameLock.unlock()

        #if os(macOS)
        mtkView?.needsDisplay = true
        #else
        mtkView?.setNeedsDisplay()
        #endif
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
        needsRedraw = true
        idleFrameCount = 0
        updateTransform()
        onFrameSubmitted?(pixelBuffer)

        DispatchQueue.main.async { [weak self] in
            guard let self = self, let view = self.mtkView else { return }
            if view.isPaused {
                view.isPaused = false
            }
        }
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

    /// Render the current frame to a drawable
    func render(to drawable: CAMetalDrawable, renderPassDescriptor: MTLRenderPassDescriptor) {
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

    // Convert linear light to EDR (scale for display)
    // SDR reference white = 203 nits, EDR 1.0 = 80 nits (SDR white)
    // So HDR 203 nits should map to EDR 203/80 = 2.5375
    float3 linearToEDR(float3 linear) {
        // linear is in 0-1 range representing 0-10000 nits
        // Scale so that SDR white (203 nits) = 1.0 in EDR
        // 203/10000 in linear = 1.0 in EDR, so multiply by 10000/203
        // But we also need to account for EDR headroom
        // Simplified: multiply by ~12.5 to map HDR range to EDR
        return linear * 12.5;
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

        float y = textureY.sample(textureSampler, in.texCoord).r;
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
            // Convert to EDR range for display
            rgb = linearToEDR(rgb);
            // Apply color adjustments in linear space
            rgb = rgb * uniforms.brightness;
            float gray = dot(rgb, float3(0.2126, 0.7152, 0.0722));
            rgb = mix(float3(gray), rgb, uniforms.saturation);
            // Clamp lower bound only (allow EDR values > 1.0)
            rgb = max(rgb, 0.0);
        } else {
            // SDR: apply adjustments in gamma space
            rgb = (rgb - 0.5) * uniforms.contrast + 0.5;
            rgb = rgb * uniforms.brightness;
            float gray = dot(rgb, float3(0.2126, 0.7152, 0.0722));
            rgb = mix(float3(gray), rgb, uniforms.saturation);
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

        float4 color = texture.sample(textureSampler, in.texCoord);
        float3 rgb = color.rgb;

        // For HDR (BT.2020), apply PQ EOTF to convert to linear light
        if (uniforms.colorSpace == 2u) {
            rgb = clamp(rgb, 0.0, 1.0);
            rgb = pqEOTF(rgb);
            rgb = linearToEDR(rgb);
            rgb = rgb * uniforms.brightness;
            float gray = dot(rgb, float3(0.2126, 0.7152, 0.0722));
            rgb = mix(float3(gray), rgb, uniforms.saturation);
            rgb = max(rgb, 0.0);
        } else {
            rgb = (rgb - 0.5) * uniforms.contrast + 0.5;
            rgb = rgb * uniforms.brightness;
            float gray = dot(rgb, float3(0.2126, 0.7152, 0.0722));
            rgb = mix(float3(gray), rgb, uniforms.saturation);
            rgb = clamp(rgb, 0.0, 1.0);
        }

        return float4(rgb, color.a);
    }
    """
}

// MARK: - MTKViewDelegate Extension

extension MetalVideoRenderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        updateViewSize(size)
    }

    func draw(in view: MTKView) {
        frameLock.lock()
        if !needsRedraw {
            idleFrameCount += 1
            
            if vrrEnabled && idleFrameCount > 5 && view.preferredFramesPerSecond > 10 {
                view.preferredFramesPerSecond = 10
            }
            
            if idleFrameCount > idleThreshold && !view.isPaused {
                view.isPaused = true
                logDebug("🔋 VRR: Paused rendering after \(idleThreshold) idle frames")
            }
            frameLock.unlock()
            return
        }

        if view.isPaused {
            logDebug("🔋 VRR: Resumed rendering (new frame received)")
        }

        needsRedraw = false
        idleFrameCount = 0
        
        if vrrEnabled && view.preferredFramesPerSecond != targetFPS {
            view.preferredFramesPerSecond = targetFPS
        }
        
        frameLock.unlock()

        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor else {
            return
        }
        render(to: drawable, renderPassDescriptor: renderPassDescriptor)
    }
}
