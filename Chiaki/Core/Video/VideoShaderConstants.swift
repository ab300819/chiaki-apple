// SPDX-License-Identifier: AGPL-3.0-only
//
// VideoShaderConstants.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Shared constants and matrices for video shaders, also used for CPU-side verification.
//
// @requirement F-025 - HDR 渲染管线优化
// @satisfies AC-080 - 色域映射
//

import Foundation
import simd

/// Constants and matrices used in video shaders
/// Values must match Chiaki/Core/Video/VideoShaders.metal
/// @satisfies AC-080
enum VideoShaderConstants {

    /// Rec.2020 to Display P3 color space conversion matrix
    /// D65 white point, linear space.
    /// References:
    /// - ITU-R BT.2020
    /// - SMPTE RP 431-2 (DCI-P3)
    /// @satisfies AC-080
    static let rec2020ToP3Matrix = simd_float3x3(
        simd_float3( 1.2249, -0.0420, -0.0197), // Column 0
        simd_float3(-0.2247,  1.0419, -0.0786), // Column 1
        simd_float3( 0.0000,  0.0000,  1.0979)  // Column 2
    )
}

/// CPU implementation of gamut mapping logic for testing and verification
/// @satisfies AC-080
func applyGamutMapping(_ color: simd_float3) -> simd_float3 {
    // 1. Matrix transformation
    let p3 = VideoShaderConstants.rec2020ToP3Matrix * color
    // 2. Soft clamping (AC-080 requirement: handle negative values)
    return max(p3, simd_float3(0, 0, 0))
}
