// SPDX-License-Identifier: AGPL-3.0-only
//
//  VideoShaderConstantsTests.swift
//  ChiakiTests
//
//  Unit tests for VideoShaderConstants (UT-044)
//
//  @requirement F-028 - HDR 配置完全落地
//  @verifies AC-100 - 单元测试覆盖
//

import Testing
import Foundation
import simd
@testable import Chiaki

struct VideoShaderConstantsTests {

    /**
     * @verifies AC-100 - PQ EOTF 黑电平
     * @testcase UT-044.1
     */
    @Test func testPQEOTF_Black() {
        let input = simd_float3(0.0, 0.0, 0.0)
        let result = VideoShaderConstants.pqEOTF(input)
        #expect(result.x == 0.0)
        #expect(result.y == 0.0)
        #expect(result.z == 0.0)
    }

    /**
     * @verifies AC-100 - PQ EOTF SDR 参考白 (203 nits)
     * @testcase UT-044.2
     */
    @Test func testPQEOTF_SDRWhite() {
        // PQ 0.508078 corresponds to 100 nits (0.01 normalized to 10000 nits)
        let input = simd_float3(0.508078, 0.508078, 0.508078)
        let result = VideoShaderConstants.pqEOTF(input)
        #expect(abs(result.x - 0.01) < 0.0001)
    }

    /**
     * @verifies AC-100 - PQ EOTF 峰值亮度 (10000 nits)
     * @testcase UT-044.3
     */
    @Test func testPQEOTF_Peak() {
        let input = simd_float3(1.0, 1.0, 1.0)
        let result = VideoShaderConstants.pqEOTF(input)
        #expect(abs(result.x - 1.0) < 0.0001)
    }

    /**
     * @verifies AC-100 - Gamut Mapping 白点保持
     * @testcase UT-044.4
     */
    @Test func testGamutMapping_White() {
        let input = simd_float3(1.0, 1.0, 1.0)
        let result = VideoShaderConstants.applyGamutMapping(input)
        // White point should remain white (D65)
        #expect(abs(result.x - 1.0) < 0.1)
        #expect(abs(result.y - 1.0) < 0.1)
        #expect(abs(result.z - 1.0) < 0.1)
    }

    /**
     * @verifies AC-100 - Gamut Mapping 无负值
     * @testcase UT-044.5
     */
    @Test func testGamutMapping_NoNegatives() {
        let input = simd_float3(0.1, 0.9, 0.1)
        let result = VideoShaderConstants.applyGamutMapping(input)
        #expect(result.x >= 0.0)
        #expect(result.y >= 0.0)
        #expect(result.z >= 0.0)
    }

    /**
     * @verifies AC-100 - ACES Tonemap 黑点
     * @testcase UT-044.6
     */
    @Test func testACES_Black() {
        let input = simd_float3(0.0, 0.0, 0.0)
        let result = VideoShaderConstants.acesTonemap(input)
        #expect(result.x == 0.0)
    }

    /**
     * @verifies AC-100 - ACES Tonemap 高亮截断
     * @testcase UT-044.7
     */
    @Test func testACES_Clamp() {
        let input = simd_float3(10.0, 10.0, 10.0)
        let result = VideoShaderConstants.acesTonemap(input)
        #expect(result.x <= 1.0)
        #expect(result.x > 0.9)
    }

    /**
     * @verifies AC-100 - BT.709 白点转换
     * @testcase UT-044.8
     */
    @Test func testBT709_WhitePoint() {
        // Y=1, U=0, V=0 should be white
        let yuv = simd_float3(1.0, 0.0, 0.0)
        let result = VideoShaderConstants.kBT709Full * yuv
        #expect(abs(result.x - 1.0) < 0.0001)
        #expect(abs(result.y - 1.0) < 0.0001)
        #expect(abs(result.z - 1.0) < 0.0001)
    }

    /**
     * @verifies AC-100 - BT.2020 矩阵加载
     * @testcase UT-044.9
     */
    @Test func testBT2020Matrix_Load() {
        let matrix = VideoShaderConstants.kBT2020Full
        #expect(matrix[0][0] == 1.0)
    }

    /**
     * @verifies AC-100 - Rec2020 to P3 矩阵加载
     * @testcase UT-044.10
     */
    @Test func testRec2020ToP3Matrix_Load() {
        let matrix = VideoShaderConstants.rec2020ToP3Matrix
        #expect(matrix[0][0] > 1.2)
    }
}
