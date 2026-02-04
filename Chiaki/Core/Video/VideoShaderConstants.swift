// SPDX-License-Identifier: AGPL-3.0-only
//
// VideoShaderConstants.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Shared constants and matrices for video shaders, also used for CPU-side verification.
//
// @requirement F-025 - HDR 渲染管线优化
// @satisfies AC-080 - 色域映射
// @satisfies AC-084 - Tone Mapping 降级
//

import Foundation
import simd

/// Constants and matrices used in video shaders
/// Values must match Chiaki/Core/Video/VideoShaders.metal
/// @satisfies AC-080
/// @satisfies AC-084
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

    /// ACES Filmic Tone Mapping fitting parameters
    /// Based on Narkowicz 2015
    /// @satisfies AC-084
    enum ACES {
        static let a: Float = 2.51
        static let b: Float = 0.03
        static let c: Float = 2.43
        static let d: Float = 0.59
        static let e: Float = 0.14
    }
}

/// CPU implementation of gamut mapping logic for testing and verification
/// @satisfies AC-080
func applyGamutMapping(_ color: simd_float3) -> simd_float3 {
    // 1. Matrix transformation
    let p3 = VideoShaderConstants.rec2020ToP3Matrix * color
    // 2. Soft clamping (AC-080 requirement: handle negative values)
    return max(p3, simd_float3(0, 0, 0))
}

/// CPU implementation of ACES Filmic Tone Mapping for testing and verification
/// [requirement] F-025
/// [satisfies] AC-084
func applyACESTonemap(_ x: simd_float3) -> simd_float3 {
    let a: Float = VideoShaderConstants.ACES.a
    let b: Float = VideoShaderConstants.ACES.b
    let c: Float = VideoShaderConstants.ACES.c
    let d: Float = VideoShaderConstants.ACES.d
    let e: Float = VideoShaderConstants.ACES.e
    
    let numerator = x * (a * x + b)
    let denominator = x * (c * x + d) + e
    let result = numerator / denominator
    
    return clamp(result, min: simd_float3(0, 0, 0), max: simd_float3(1, 1, 1))
}

// Helper clamp for SIMD
private func clamp(_ x: simd_float3, min: simd_float3, max: simd_float3) -> simd_float3 {
    return simd.max(min, simd.min(x, max))
}
