// SPDX-License-Identifier: AGPL-3.0-only
//
//  VideoUniformsTests.swift
//  ChiakiTests
//
//  Unit tests for VideoUniforms structure extension (T-171)
//
//  @requirement F-028 - HDR 配置完全落地
//  @verifies AC-097 - Shader 动态分支
//  @verifies AC-098 - EDR 强度应用
//  @verifies AC-099 - 色域映射开关
//

import Testing
import Foundation
import simd
@testable import Chiaki

struct VideoUniformsTests {

    /**
     * @verifies AC-098 - EDR 强度应用
     * @testcase UT-042.1
     */
    @Test func testVideoUniformsHasEDRIntensity() {
        let uniforms = VideoUniforms.default
        // This should fail to compile if field is missing
        #expect(uniforms.edrIntensity == 1.0)
    }

    /**
     * @verifies AC-099 - 色域映射开关
     * @testcase UT-042.2
     */
    @Test func testVideoUniformsHasGamutMappingEnabled() {
        let uniforms = VideoUniforms.default
        // This should fail to compile if field is missing
        #expect(uniforms.gamutMappingEnabled == 1)
    }

    /**
     * @verifies AC-097 - Shader 动态分支
     * @testcase UT-042.3
     */
    @Test func testVideoUniformsAlignment() {
        // Struct size should be a multiple of 16 bytes for Metal constant buffer alignment
        let size = MemoryLayout<VideoUniforms>.size
        #expect(size % 16 == 0, "VideoUniforms size (\(size)) should be 16-byte aligned")
    }

    /**
     * @verifies AC-097 - Shader 动态分支
     * @testcase UT-042.4
     */
    @Test func testVideoUniformsDefaultValues() {
        let uniforms = VideoUniforms.default
        #expect(uniforms.edrIntensity == 1.0)
        #expect(uniforms.gamutMappingEnabled == 1)
    }
}
