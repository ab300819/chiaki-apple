// SPDX-License-Identifier: AGPL-3.0-only
//
//  PlaceboTextureImportTests.swift
//  ChiakiTests
//
//  @requirement F-042 - libplacebo 渲染后端集成
//  @verifies AC-174 - 零拷贝纹理导入
//

import Testing
import Foundation
import CoreVideo
@testable import Chiaki

@Suite("UT-062 Placebo 零拷贝纹理导入验证")
struct PlaceboTextureImportTests {

    private func requireRenderer() throws -> PlaceboVideoRenderer {
        guard let renderer = PlaceboVideoRenderer() else {
            throw Skip("PlaceboVideoRenderer not available (missing libplacebo/MoltenVK frameworks)")
        }
        return renderer
    }

    private func createTestPixelBuffer(format: OSType, width: Int, height: Int) -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            format,
            [kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary,
            &pixelBuffer
        )
        #expect(status == kCVReturnSuccess)
        return pixelBuffer!
    }

    /**
     * @verifies AC-174
     * @testcase UT-062.1
     */
    @Test("提交 NV12 CVPixelBuffer：基本状态更新")
    func testSubmitFrameNV12() throws {
        let renderer = try requireRenderer()
        let buffer = createTestPixelBuffer(format: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, width: 1920, height: 1080)
        
        renderer.submitFrame(buffer)
        
        #expect(renderer.hasFrame == true)
        #expect(renderer.frameSize == CGSize(width: 1920, height: 1080))
    }

    /**
     * @verifies AC-174
     * @testcase UT-062.2
     */
    @Test("提交 P010 HDR CVPixelBuffer：尺寸识别")
    func testSubmitFrameP010() throws {
        let renderer = try requireRenderer()
        let buffer = createTestPixelBuffer(format: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange, width: 3840, height: 2160)
        
        renderer.submitFrame(buffer)
        
        #expect(renderer.hasFrame == true)
        #expect(renderer.frameSize == CGSize(width: 3840, height: 2160))
    }

    /**
     * @verifies AC-174
     * @testcase UT-062.4
     */
    @Test("连续提交：状态覆盖验证")
    func testContinuousSubmit() throws {
        let renderer = try requireRenderer()
        
        let buffer1 = createTestPixelBuffer(format: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, width: 1280, height: 720)
        renderer.submitFrame(buffer1)
        #expect(renderer.frameSize == CGSize(width: 1280, height: 720))
        
        let buffer2 = createTestPixelBuffer(format: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, width: 1920, height: 1080)
        renderer.submitFrame(buffer2)
        #expect(renderer.frameSize == CGSize(width: 1920, height: 1080))
    }
}
