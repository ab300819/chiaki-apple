// SPDX-License-Identifier: AGPL-3.0-only
//
//  VideoShaderConstants.swift
//  Chiaki
//
//  CPU-side implementations of Metal shader constants and functions for verification.
//
//  @requirement F-028 - HDR 配置完全落地
//  @satisfies AC-100 - 单元测试覆盖
//

import Foundation
import simd

public enum VideoShaderConstants {

    // MARK: - PQ (ST 2084) EOTF Constants
    
    public static let pq_m1: Float = 0.1593017578125
    public static let pq_m2: Float = 78.84375
    public static let pq_c1: Float = 0.8359375
    public static let pq_c2: Float = 18.8515625
    public static let pq_c3: Float = 18.6875

    // MARK: - Color Conversion Matrices (Column-Major)

    public static let kBT709Full = simd_float3x3(
        simd_float3(1.0, 1.0, 1.0),
        simd_float3(0.0, -0.18732, 1.85560),
        simd_float3(1.57480, -0.46812, 0.0)
    )

    public static let kBT2020Full = simd_float3x3(
        simd_float3(1.0, 1.0, 1.0),
        simd_float3(0.0, -0.16455, 1.88140),
        simd_float3(1.47460, -0.57135, 0.0)
    )

    public static let rec2020ToP3Matrix = simd_float3x3(
        simd_float3(1.2249, -0.0420, -0.0197),
        simd_float3(-0.2247, 1.0419, -0.0786),
        simd_float3(0.0000, 0.0000, 1.0979)
    )

    // MARK: - CPU Functions

    /**
     * PQ EOTF: Convert PQ-encoded value to linear light
     * @requirement F-028
     * @satisfies AC-100
     */
    public static func pqEOTF(_ pq: simd_float3) -> simd_float3 {
        // Implementation for T-172
        let p = pow(simd.max(pq, simd_float3(0, 0, 0)), simd_float3(repeating: 1.0 / pq_m2))
        let num = simd.max(p - pq_c1, simd_float3(0, 0, 0))
        let den = pq_c2 - pq_c3 * p
        return pow(num / den, simd_float3(repeating: 1.0 / pq_m1))
    }

    /**
     * Rec.2020 -> Display P3 gamut mapping
     * @requirement F-028
     * @satisfies AC-100
     */
    public static func applyGamutMapping(_ color: simd_float3) -> simd_float3 {
        // Implementation for T-172
        let p3 = rec2020ToP3Matrix * color
        return simd.max(p3, simd_float3(0, 0, 0))
    }

    /**
     * ACES Filmic Tone Mapping
     * @requirement F-028
     * @satisfies AC-100
     */
    public static func acesTonemap(_ x: simd_float3) -> simd_float3 {
        // Implementation for T-172
        let a: Float = 2.51
        let b: Float = 0.03
        let c: Float = 2.43
        let d: Float = 0.59
        let e: Float = 0.14
        let result = (x * (a * x + b)) / (x * (c * x + d) + e)
        return simd.max(simd_float3(0, 0, 0), simd.min(result, simd_float3(1, 1, 1)))
    }
}

// MARK: - Compatibility Aliases

/**
 * @verifies AC-080
 */
public func applyGamutMapping(_ color: simd_float3) -> simd_float3 {
    VideoShaderConstants.applyGamutMapping(color)
}

/**
 * @verifies AC-084
 */
public func applyACESTonemap(_ x: simd_float3) -> simd_float3 {
    VideoShaderConstants.acesTonemap(x)
}

