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

    private var rawContext: UnsafeMutablePointer<ChiakiPlaceboContext>?
    
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
        guard let context = rawContext else { return nil }
        return wrap(ChiakiPlaceboContextCreateLog(context))
    }

    func createVulkanDevice() -> OpaquePointer? {
        guard let context = rawContext else { return nil }
        return wrap(ChiakiPlaceboContextCreateVulkanDevice(context))
    }

    func createRenderer() -> OpaquePointer? {
        guard let context = rawContext else { return nil }
        return wrap(ChiakiPlaceboContextCreateRenderer(context))
    }

    func destroyRenderer() {
        guard let context = rawContext else { return }
        ChiakiPlaceboContextDestroyRenderer(context)
    }

    func destroyVulkanDevice() {
        guard let context = rawContext else { return }
        ChiakiPlaceboContextDestroyVulkanDevice(context)
    }

    func destroyLog() {
        guard let context = rawContext else { return }
        ChiakiPlaceboContextDestroyLog(context)
    }

    var logHandle: OpaquePointer? {
        guard let context = rawContext else { return nil }
        return wrap(ChiakiPlaceboContextGetLog(context))
    }

    var vulkanHandle: OpaquePointer? {
        guard let context = rawContext else { return nil }
        return wrap(ChiakiPlaceboContextGetVulkanDevice(context))
    }

    var rendererHandle: OpaquePointer? {
        guard let context = rawContext else { return nil }
        return wrap(ChiakiPlaceboContextGetRenderer(context))
    }
}
