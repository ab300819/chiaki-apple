// SPDX-License-Identifier: AGPL-3.0-only
//
//  VideoRendererTests.swift
//  ChiakiTests
//
//  Unit tests for VideoRenderer protocol (T-156)
//
//  @requirement F-026 - 渲染模块解耦重构
//  @verifies AC-086 - 协议抽象接口
//

import Testing
import Foundation
import CoreVideo
import MetalKit
@testable import Chiaki

/// Helper to create test pixel buffers for testing
private func createTestPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
    var pixelBuffer: CVPixelBuffer?
    let attributes: [CFString: Any] = [
        kCVPixelBufferWidthKey: width,
        kCVPixelBufferHeightKey: height,
        kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
        kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
    ]

    let status = CVPixelBufferCreate(
        kCFAllocatorDefault,
        width,
        height,
        kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
        attributes as CFDictionary,
        &pixelBuffer
    )

    return status == kCVReturnSuccess ? pixelBuffer : nil
}

@MainActor
struct VideoRendererProtocolTests {

    // MARK: - UT-033.1: Protocol Conformance

    /**
     * @verifies AC-086 - 协议抽象接口
     * @testcase UT-033.1
     */
    @Test func testRendererConformsToProtocol() throws {
        let renderer = MetalVideoRenderer()
        #expect(renderer != nil)

        // Type check: MetalVideoRenderer should conform to VideoRenderer protocol
        let protocolRenderer: (any VideoRenderer)? = renderer
        #expect(protocolRenderer != nil)
    }

    // MARK: - UT-033.2: Frame Submission

    /**
     * @verifies AC-086 - 协议抽象接口
     * @testcase UT-033.2
     */
    @Test func testSubmitFrameUpdatesBuffer() throws {
        guard let renderer = MetalVideoRenderer() else {
            throw TestError("Failed to create MetalVideoRenderer")
        }

        // Initially no frame
        #expect(renderer.hasFrame == false)

        // Submit a test frame
        guard let pixelBuffer = createTestPixelBuffer(width: 1920, height: 1080) else {
            throw TestError("Failed to create test pixel buffer")
        }

        renderer.submitFrame(pixelBuffer)

        // After submission, hasFrame should be true
        #expect(renderer.hasFrame == true)
    }

    // MARK: - UT-033.3: Frame Size Calculation

    /**
     * @verifies AC-086 - 协议抽象接口
     * @testcase UT-033.3
     */
    @Test func testFrameSizeCalculation() throws {
        guard let renderer = MetalVideoRenderer() else {
            throw TestError("Failed to create MetalVideoRenderer")
        }

        // Submit a frame with known dimensions
        guard let pixelBuffer = createTestPixelBuffer(width: 1920, height: 1080) else {
            throw TestError("Failed to create test pixel buffer")
        }

        renderer.submitFrame(pixelBuffer)

        // frameSize should match the pixel buffer dimensions
        #expect(renderer.frameSize.width == 1920)
        #expect(renderer.frameSize.height == 1080)
    }

    // MARK: - UT-033.4: Display Mode Property

    /**
     * @verifies AC-086 - 协议抽象接口
     * @testcase UT-033.4
     */
    @Test func testDisplayModeProperty() throws {
        guard let renderer = MetalVideoRenderer() else {
            throw TestError("Failed to create MetalVideoRenderer")
        }

        // Default should be normal
        #expect(renderer.displayMode == .normal)

        // Set to stretch
        renderer.displayMode = .stretch
        #expect(renderer.displayMode == .stretch)

        // Set to zoom
        renderer.displayMode = .zoom
        #expect(renderer.displayMode == .zoom)
    }

    // MARK: - UT-033.5: Zoom Factor Property

    /**
     * @verifies AC-086 - 协议抽象接口
     * @testcase UT-033.5
     */
    @Test func testZoomFactorProperty() throws {
        guard let renderer = MetalVideoRenderer() else {
            throw TestError("Failed to create MetalVideoRenderer")
        }

        // Default should be 1.0
        #expect(renderer.zoomFactor == 1.0)

        // Set to 1.5
        renderer.zoomFactor = 1.5
        #expect(renderer.zoomFactor == 1.5)

        // Set to 2.0
        renderer.zoomFactor = 2.0
        #expect(renderer.zoomFactor == 2.0)
    }

    // MARK: - UT-033.6: Color Adjustment Methods

    /**
     * @verifies AC-086 - 协议抽象接口
     * @testcase UT-033.6
     */
    @Test func testColorAdjustmentMethods() throws {
        guard let renderer = MetalVideoRenderer() else {
            throw TestError("Failed to create MetalVideoRenderer")
        }

        // These methods should not throw
        renderer.setBrightness(1.2)
        renderer.setContrast(0.9)
        renderer.setSaturation(1.1)

        // Verify no crash - methods are fire-and-forget
        #expect(true)
    }

    // MARK: - UT-034.1: HDR Configuration

    /**
     * @verifies AC-088 - HDR 配置结构
     * @testcase UT-034.1
     */
    @Test func testRendererAcceptsHDRConfiguration() throws {
        guard let renderer = MetalVideoRenderer() else {
            throw TestError("Failed to create MetalVideoRenderer")
        }

        // Set HDR configuration
        let config = HDRConfiguration.hdr
        renderer.hdrConfiguration = config

        #expect(renderer.hdrConfiguration.enabled == true)
        #expect(renderer.hdrConfiguration.colorSpace == .bt2020)
    }

    // MARK: - UT-034.3: EDR Headroom Injection

    /**
     * @verifies AC-081 - EDR Headroom 动态监听
     * @testcase UT-034.3
     */
    @Test func testEDRHeadroomInjection() throws {
        guard let renderer = MetalVideoRenderer() else {
            throw TestError("Failed to create MetalVideoRenderer")
        }

        // Set EDR headroom
        renderer.edrHeadroom = 2.5
        #expect(renderer.edrHeadroom == 2.5)

        // Minimum should be 1.0
        renderer.edrHeadroom = 0.5
        #expect(renderer.edrHeadroom >= 1.0)
    }
}

// MARK: - BUG-020: Shader Compilation Regression Test

@MainActor
struct ShaderCompilationTests {

    /**
     * @verifies BUG-020 - Metal shader 'constant' keyword misuse causes compilation failure
     *
     * Regression test: MetalVideoRenderer uses runtime shader compilation via
     * device.makeLibrary(source:). If the shader source contains Metal language errors
     * (e.g., using 'constant' as a local variable qualifier instead of 'const'),
     * compilation fails silently and the renderer returns nil, causing a black screen.
     */
    @Test func testShaderSourceCompilesSuccessfully() throws {
        guard let renderer = MetalVideoRenderer() else {
            throw TestError("MetalVideoRenderer init returned nil — shader compilation likely failed")
        }

        // If we get here, the shader compiled and all pipeline states were created
        #expect(renderer.frameCount == 0)
        #expect(renderer.droppedFrameCount == 0)
    }

    /**
     * @verifies BUG-020 - Filter config is accessible after successful compilation
     */
    @Test func testFilterConfigDefaultAfterInit() throws {
        guard let renderer = MetalVideoRenderer() else {
            throw TestError("MetalVideoRenderer init returned nil")
        }

        #expect(renderer.filterConfig == .default)
        #expect(renderer.filterName == "Bicubic")
    }
}

// MARK: - Test Error Helper

private struct TestError: Error, CustomStringConvertible {
    let message: String
    var description: String { message }

    init(_ message: String) {
        self.message = message
    }
}
