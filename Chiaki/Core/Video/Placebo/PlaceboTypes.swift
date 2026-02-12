// SPDX-License-Identifier: AGPL-3.0-only
//
// PlaceboTypes.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Swift-facing type mapping and lifecycle wrapper for libplacebo C bridge.
//
// @requirement F-042 - libplacebo 渲染后端集成
// @satisfies AC-173 - PlaceboVideoRenderer 协议实现（桥接前置）

import Foundation

/// Render preset mapping used by libplacebo backend.
/// T-247 will bind these values to concrete `pl_render_params` presets.
enum PlaceboRenderPreset: String, CaseIterable, Sendable {
    case performance
    case `default`
    case highQuality
}

enum PlaceboUpscalerMode: Int32, Equatable, Sendable {
    case bilinear = 0
    case lanczos = 1
    case ewaLanczosSharp = 2
}

/// Swift-side render parameter mapping for libplacebo.
struct PlaceboRenderParams: Equatable, Sendable {
    var preset: PlaceboRenderPreset
    var enableDeband: Bool
    var enableSigmoidUpScaling: Bool
    var upscaler: PlaceboUpscalerMode
    var tonemapEnabled: Bool
    var targetMaxLuma: Float
    var colorSpace: UInt32

    static let performance = PlaceboRenderParams(
        preset: .performance,
        enableDeband: false,
        enableSigmoidUpScaling: false,
        upscaler: .bilinear,
        tonemapEnabled: false,
        targetMaxLuma: 203.0,
        colorSpace: 0
    )

    static let `default` = PlaceboRenderParams(
        preset: .default,
        enableDeband: true,
        enableSigmoidUpScaling: true,
        upscaler: .lanczos,
        tonemapEnabled: false,
        targetMaxLuma: 203.0,
        colorSpace: 0
    )

    static let highQuality = PlaceboRenderParams(
        preset: .highQuality,
        enableDeband: true,
        enableSigmoidUpScaling: true,
        upscaler: .ewaLanczosSharp,
        tonemapEnabled: false,
        targetMaxLuma: 203.0,
        colorSpace: 0
    )

    static func map(
        filterConfig: VideoFilterConfig,
        hdrConfiguration: HDRConfiguration,
        edrHeadroom: Float,
        colorSpace: UInt32
    ) -> PlaceboRenderParams {
        var params: PlaceboRenderParams
        if filterConfig == .performance {
            params = .performance
        } else if filterConfig == .highQuality {
            params = .highQuality
        } else {
            params = .default
        }

        let hdrEnabled = hdrConfiguration.isHDR
        params.tonemapEnabled = hdrEnabled
        params.targetMaxLuma = max(203.0, max(1.0, edrHeadroom) * 203.0)
        params.colorSpace = min(colorSpace, 2)
        return params
    }
}

/// Swift-side deband tuning mapping for libplacebo.
struct PlaceboDebandParams: Equatable, Sendable {
    var iterations: UInt32
    var threshold: Float
    var radius: Float
    var grain: Float

    static let `default` = PlaceboDebandParams(
        iterations: 1,
        threshold: 4.0,
        radius: 16.0,
        grain: 4.0
    )

    static let disabled = PlaceboDebandParams(
        iterations: 0,
        threshold: 0,
        radius: 0,
        grain: 0
    )
}

struct PlaceboColorAdjustment: Equatable, Sendable {
    var brightness: Float = 1.0
    var contrast: Float = 1.0
    var saturation: Float = 1.0

    mutating func updateBrightness(_ value: Float) {
        brightness = clamp(value)
    }

    mutating func updateContrast(_ value: Float) {
        contrast = clamp(value)
    }

    mutating func updateSaturation(_ value: Float) {
        saturation = clamp(value)
    }

    private func clamp(_ value: Float) -> Float {
        max(0.0, min(2.0, value))
    }
}

struct PlaceboFrameParams: Equatable, Sendable {
    var render: PlaceboRenderParams
    var deband: PlaceboDebandParams
    var adjustment: PlaceboColorAdjustment

    static func map(
        filterConfig: VideoFilterConfig,
        hdrConfiguration: HDRConfiguration,
        edrHeadroom: Float,
        adjustment: PlaceboColorAdjustment,
        colorSpace: UInt32
    ) -> PlaceboFrameParams {
        let render = PlaceboRenderParams.map(
            filterConfig: filterConfig,
            hdrConfiguration: hdrConfiguration,
            edrHeadroom: edrHeadroom,
            colorSpace: colorSpace
        )
        let deband: PlaceboDebandParams = render.enableDeband ? .default : .disabled
        return PlaceboFrameParams(render: render, deband: deband, adjustment: adjustment)
    }

    var bridgeValue: ChiakiPlaceboFrameParams {
        var params = ChiakiPlaceboFrameParams()
        switch render.preset {
        case .performance:
            params.preset = CHIAKI_PLACEBO_RENDER_PRESET_PERFORMANCE
        case .default:
            params.preset = CHIAKI_PLACEBO_RENDER_PRESET_DEFAULT
        case .highQuality:
            params.preset = CHIAKI_PLACEBO_RENDER_PRESET_HIGH_QUALITY
        }

        switch render.upscaler {
        case .bilinear:
            params.upscaler = CHIAKI_PLACEBO_UPSCALER_BILINEAR
        case .lanczos:
            params.upscaler = CHIAKI_PLACEBO_UPSCALER_LANCZOS
        case .ewaLanczosSharp:
            params.upscaler = CHIAKI_PLACEBO_UPSCALER_EWA_LANCZOSSHARP
        }

        params.tonemapEnabled = render.tonemapEnabled
        params.targetMaxLuma = render.targetMaxLuma
        params.colorSpace = render.colorSpace
        params.deband.enabled = deband.iterations > 0
        params.deband.iterations = deband.iterations
        params.deband.threshold = deband.threshold
        params.deband.radius = deband.radius
        params.deband.grain = deband.grain
        params.adjustment.brightness = adjustment.brightness
        params.adjustment.contrast = adjustment.contrast
        params.adjustment.saturation = adjustment.saturation
        return params
    }
}

/// Vulkan bootstrap parameters used by bridge init.
/// Includes mandatory extension for MoltenVK interop path in Phase 1.
struct PlaceboVulkanConfig: Equatable, Sendable {
    var requiredInstanceExtensions: [String]

    static let `default` = PlaceboVulkanConfig(
        requiredInstanceExtensions: [
            "VK_KHR_surface",
            "VK_EXT_metal_surface",
            "VK_EXT_metal_objects"
        ]
    )
}

/// Swift lifecycle owner for C bridge resources.
///
/// This wrapper intentionally keeps bridge calls minimal:
/// - T-244: context/log/vulkan/renderer handle lifecycle
/// - T-245+: replace token handles with real libplacebo object pointers
///
/// @requirement F-042
/// @satisfies AC-173
final class PlaceboContext {

    private var rawContext: OpaquePointer?
    
    private func wrap(_ pointer: UnsafeMutableRawPointer?) -> OpaquePointer? {
        guard let pointer else { return nil }
        return OpaquePointer(pointer)
    }

    init?() {
        guard let context = ChiakiPlaceboContextCreate() else {
            return nil
        }
        self.rawContext = context
    }

    deinit {
        ChiakiPlaceboContextDestroy(rawContext)
    }

    var isAvailable: Bool {
        ChiakiPlaceboContextIsAvailable(rawContext)
    }

    var hasMetalObjectsExtension: Bool {
        ChiakiPlaceboContextHasMetalObjectsExtension(rawContext)
    }

    func createLog() -> OpaquePointer? {
        return wrap(ChiakiPlaceboContextCreateLog(rawContext))
    }

    func createVulkanDevice() -> OpaquePointer? {
        return wrap(ChiakiPlaceboContextCreateVulkanDevice(rawContext))
    }

    func createRenderer() -> OpaquePointer? {
        return wrap(ChiakiPlaceboContextCreateRenderer(rawContext))
    }

    func destroyRenderer() {
        ChiakiPlaceboContextDestroyRenderer(rawContext)
    }

    func destroyVulkanDevice() {
        ChiakiPlaceboContextDestroyVulkanDevice(rawContext)
    }

    func destroyLog() {
        ChiakiPlaceboContextDestroyLog(rawContext)
    }

    var logHandle: OpaquePointer? {
        return wrap(ChiakiPlaceboContextGetLog(rawContext))
    }

    var vulkanHandle: OpaquePointer? {
        return wrap(ChiakiPlaceboContextGetVulkanDevice(rawContext))
    }

    var rendererHandle: OpaquePointer? {
        return wrap(ChiakiPlaceboContextGetRenderer(rawContext))
    }

    func destroyTexture(_ tex: OpaquePointer) {
        ChiakiPlaceboContextDestroyTexture(rawContext, UnsafeMutableRawPointer(tex))
    }

    func wrapIOSurface(_ ioSurface: UnsafeMutableRawPointer, plane: Int) -> OpaquePointer? {
        return wrap(ChiakiPlaceboContextWrapIOSurface(rawContext, ioSurface, Int32(plane)))
    }

    func renderFrame(
        targetSurface: UnsafeMutableRawPointer,
        srcTexY: OpaquePointer,
        srcTexUV: OpaquePointer?,
        width: Int,
        height: Int,
        isHDR: Bool,
        frameParams: PlaceboFrameParams? = nil
    ) -> Bool {
        if let frameParams {
            var bridgeParams = frameParams.bridgeValue
            return ChiakiPlaceboContextRenderFrameEx(
                rawContext,
                targetSurface,
                UnsafeMutableRawPointer(srcTexY),
                srcTexUV != nil ? UnsafeMutableRawPointer(srcTexUV!) : nil,
                Int32(width),
                Int32(height),
                isHDR,
                &bridgeParams
            )
        }

        return ChiakiPlaceboContextRenderFrame(
            rawContext,
            targetSurface,
            UnsafeMutableRawPointer(srcTexY),
            srcTexUV != nil ? UnsafeMutableRawPointer(srcTexUV!) : nil,
            Int32(width),
            Int32(height),
            isHDR
        )
    }
}
