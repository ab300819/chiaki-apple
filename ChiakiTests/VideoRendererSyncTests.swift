// SPDX-License-Identifier: AGPL-3.0-only
//
//  VideoRendererSyncTests.swift
//  ChiakiTests
//
//  Unit tests for MetalVideoRenderer configuration synchronization (T-173)
//
//  @requirement F-028 - HDR 配置完全落地
//  @verifies AC-097 - Shader 动态分支
//  @verifies AC-098 - EDR 强度应用
//  @verifies AC-099 - 色域映射开关
//

import Testing
import Foundation
import CoreVideo
import MetalKit
@testable import Chiaki

@MainActor
struct VideoRendererSyncTests {

    /**
     * @verifies AC-097, AC-098, AC-099
     * @testcase UT-043.1
     */
    @Test func testHDRConfigurationSync() throws {
        guard let renderer = MetalVideoRenderer() else {
            throw TestError("Failed to create MetalVideoRenderer")
        }

        var config = HDRConfiguration.hdr
        config.edrIntensity = 1.5
        config.gamutMappingEnabled = false
        
        renderer.hdrConfiguration = config
        
        // Internal uniforms should be updated (we verify via public getters or effects if possible)
        // Since uniforms is private, we verify that the configuration property itself is correct
        // and we will rely on the methods we're about to add.
        #expect(renderer.hdrConfiguration.edrIntensity == 1.5)
        #expect(renderer.hdrConfiguration.gamutMappingEnabled == false)
    }

    /**
     * @verifies AC-098 - EDR 强度实时预览
     * @testcase UT-043.2
     */
    @Test func testSetEDRIntensity() throws {
        guard let renderer = MetalVideoRenderer() else {
            throw TestError("Failed to create MetalVideoRenderer")
        }

        renderer.setEDRIntensity(1.8)
        #expect(renderer.hdrConfiguration.edrIntensity == 1.8)
        
        // Clamp testing
        renderer.setEDRIntensity(0.1) // Below min 0.5
        #expect(renderer.hdrConfiguration.edrIntensity == 0.5)
        
        renderer.setEDRIntensity(3.0) // Above max 2.0
        #expect(renderer.hdrConfiguration.edrIntensity == 2.0)
    }

    /**
     * @verifies AC-099 - 色域映射实时预览
     * @testcase UT-043.3
     */
    @Test func testSetGamutMappingEnabled() throws {
        guard let renderer = MetalVideoRenderer() else {
            throw TestError("Failed to create MetalVideoRenderer")
        }

        renderer.setGamutMappingEnabled(false)
        #expect(renderer.hdrConfiguration.gamutMappingEnabled == false)
        
        renderer.setGamutMappingEnabled(true)
        #expect(renderer.hdrConfiguration.gamutMappingEnabled == true)
    }
}

private struct TestError: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
    init(_ message: String) { self.message = message }
}
