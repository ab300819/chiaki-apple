// SPDX-License-Identifier: AGPL-3.0-only
//
// ColorSpaceConversionTests.swift
// ChiakiTests
//
// Unit tests for color space conversion and gamut mapping math.
// @requirement F-025 - HDR 渲染管线优化
//

import XCTest
import simd
@testable import Chiaki

/// @verifies AC-080 - 色域映射
final class ColorSpaceConversionTests: XCTestCase {

    // MARK: - UT-027.1: Matrix Constants Verification

    /// @verifies AC-080
    /// @testcase UT-027.1
    func testRec2020ToP3MatrixValues() {
        let matrix = VideoShaderConstants.rec2020ToP3Matrix
        
        // Verify determinant is non-zero (invertible)
        XCTAssertNotEqual(matrix.determinant, 0, accuracy: 0.001, "矩阵应为可逆矩阵")
        
        // Verify specific values against design document
        // Matrix is column-major: float3x3(col0, col1, col2)
        XCTAssertEqual(matrix[0, 0], 1.2249, accuracy: 0.0001)
        XCTAssertEqual(matrix[1, 0], -0.2247, accuracy: 0.0001)
        XCTAssertEqual(matrix[2, 0], 0.0000, accuracy: 0.0001)
        
        XCTAssertEqual(matrix[0, 1], -0.0420, accuracy: 0.0001)
        XCTAssertEqual(matrix[1, 1], 1.0419, accuracy: 0.0001)
        XCTAssertEqual(matrix[2, 1], 0.0000, accuracy: 0.0001)
        
        XCTAssertEqual(matrix[0, 2], -0.0197, accuracy: 0.0001)
        XCTAssertEqual(matrix[1, 2], -0.0786, accuracy: 0.0001)
        XCTAssertEqual(matrix[2, 2], 1.0979, accuracy: 0.0001)
    }

    // MARK: - UT-027.2: White Point Mapping

    /// @verifies AC-080
    /// @testcase UT-027.2
    func testGamutMappingWhitePoint() {
        // Pure white in Rec.2020 should map to pure white in P3 (both D65)
        let whiteRec2020 = simd_float3(1, 1, 1)
        let mapped = applyGamutMapping(whiteRec2020)
        
        XCTAssertEqual(mapped.x, 1.0, accuracy: 0.05, "白点映射应接近 1.0")
        XCTAssertEqual(mapped.y, 1.0, accuracy: 0.05, "白点映射应接近 1.0")
        XCTAssertEqual(mapped.z, 1.0, accuracy: 0.05, "白点映射应接近 1.0")
    }

    // MARK: - UT-027.6: Negative Value Clamping

    /// @verifies AC-080
    /// @testcase UT-027.6
    func testGamutMappingNegativeClamp() {
        // Test with a value that would result in negative components (out of gamut)
        // High intensity blue in Rec.2020 might result in negative R/G in P3
        let outOfGamut = simd_float3(-0.1, 1.2, 0.5)
        let mapped = applyGamutMapping(outOfGamut)
        
        XCTAssertGreaterThanOrEqual(mapped.x, 0, "负值应被裁剪为 0")
        XCTAssertGreaterThanOrEqual(mapped.y, 0, "负值应被裁剪为 0")
        XCTAssertGreaterThanOrEqual(mapped.z, 0, "负值应被裁剪为 0")
        
        XCTAssertFalse(mapped.x.isNaN, "不应产生 NaN")
        XCTAssertFalse(mapped.y.isNaN, "不应产生 NaN")
        XCTAssertFalse(mapped.z.isNaN, "不应产生 NaN")
    }
    
    // MARK: - UT-027.3~5: Primaries Mapping (Qualitative)
    
    /// @verifies AC-080
    func testGamutMappingPrimaries() {
        // Rec.2020 Red (1,0,0) -> P3 (larger than 1 or negative components before clamp)
        let red2020 = simd_float3(1, 0, 0)
        let mappedRed = VideoShaderConstants.rec2020ToP3Matrix * red2020
        XCTAssertGreaterThan(mappedRed.x, 1.0, "Rec.2020 红在 P3 中应超出 1.0 (饱和度更高)")
        XCTAssertLessThan(mappedRed.y, 0.0, "Rec.2020 红在 P3 中可能有负分量")
    }
}
