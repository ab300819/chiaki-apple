// SPDX-License-Identifier: AGPL-3.0-only
//
// VideoFilterConfig.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Configuration model for Metal video filter pipeline parameters.
//
// @requirement F-041 - Metal 原生高质量视频滤波管线
// @satisfies AC-159 - Bicubic 9-tap 参数通道
// @satisfies AC-161 - CAS 锐化强度参数
// @satisfies AC-163 - 去色带+抖动参数

import Foundation

/// Configuration for the Metal video filter pipeline.
/// Maps directly to VideoUniforms shader fields.
struct VideoFilterConfig: Equatable, Sendable {

    /// Upscale filter mode: 0 = bilinear, 1 = bicubic Catmull-Rom
    var upscaleFilter: UInt32

    /// CAS (Contrast Adaptive Sharpening) strength: 0.0 = off, 1.0 = maximum
    var casStrength: Float

    /// Whether debanding is enabled: 0 = off, 1 = on
    var debandEnabled: UInt32

    /// Deband threshold: lower = less smoothing (typical range: 0.002 - 0.008)
    var debandThreshold: Float

    /// Deband grain / dither intensity (typical range: 0.001 - 0.006)
    var debandGrain: Float

    // MARK: - Presets

    /// Performance preset: bilinear sampling, no sharpening, no debanding
    static let performance = VideoFilterConfig(
        upscaleFilter: 0,
        casStrength: 0.0,
        debandEnabled: 0,
        debandThreshold: 0.0,
        debandGrain: 0.0
    )

    /// Default preset: bicubic upsampling, moderate CAS, deband enabled
    static let `default` = VideoFilterConfig(
        upscaleFilter: 1,
        casStrength: 0.5,
        debandEnabled: 1,
        debandThreshold: 0.004,
        debandGrain: 0.003
    )

    /// High quality preset: bicubic upsampling, strong CAS, deband with more grain
    static let highQuality = VideoFilterConfig(
        upscaleFilter: 1,
        casStrength: 0.7,
        debandEnabled: 1,
        debandThreshold: 0.004,
        debandGrain: 0.004
    )
}
