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

/// Swift-side render parameter mapping for libplacebo.
struct PlaceboRenderParams: Equatable, Sendable {
    var preset: PlaceboRenderPreset
    var enableDeband: Bool
    var enableSigmoidUpScaling: Bool

    static let performance = PlaceboRenderParams(
        preset: .performance,
        enableDeband: false,
        enableSigmoidUpScaling: false
    )

    static let `default` = PlaceboRenderParams(
        preset: .default,
        enableDeband: true,
        enableSigmoidUpScaling: true
    )

    static let highQuality = PlaceboRenderParams(
        preset: .highQuality,
        enableDeband: true,
        enableSigmoidUpScaling: true
    )
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
        isHDR: Bool
    ) -> Bool {
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
