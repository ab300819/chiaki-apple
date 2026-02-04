// SPDX-License-Identifier: AGPL-3.0-only
//
// VideoRendererHDRTests.swift
// ChiakiTests
//
// Integration tests for MetalVideoRenderer HDR mode switching and jitter suppression.
// @requirement F-025 - HDR 渲染管线优化
//

import XCTest
import CoreVideo
@testable import Chiaki

/// @verifies AC-083 - 元数据抖动抑制
final class VideoRendererHDRTests: XCTestCase {
    
    var renderer: MetalVideoRenderer!
    
    override func setUp() {
        super.setUp()
        // Initialize renderer (may return nil if Metal not available, though tests usually run on macOS)
        renderer = MetalVideoRenderer()
        XCTAssertNotNil(renderer, "Renderer initialization failed")
    }
    
    override func tearDown() {
        renderer = nil
        super.tearDown()
    }
    
    // MARK: - Helpers
    
    private func createPixelBuffer(format: OSType, width: Int = 1920, height: Int = 1080) -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            format,
            nil,
            &pixelBuffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        return pixelBuffer!
    }
    
    private func submitFrames(count: Int, format: OSType) {
        let buffer = createPixelBuffer(format: format)
        for _ in 0..<count {
            renderer.submitFrame(buffer)
        }
    }
    
    // MARK: - IT-011.1: Automatic HDR Detection
    
    /// @verifies AC-083
    /// @testcase IT-011.1
    func testAutomaticHDRDetectionWithJitterSuppression() {
        // Initial state should be SDR
        XCTAssertFalse(renderer.hdrConfiguration.isHDR, "Initial state should be SDR")
        
        // 1. Submit 4 HDR frames (P010) - should NOT switch yet
        submitFrames(count: 4, format: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange)
        XCTAssertFalse(renderer.hdrConfiguration.isHDR, "Should NOT switch to HDR after 4 frames")
        
        // 2. Submit 5th HDR frame - should switch to HDR
        submitFrames(count: 1, format: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange)
        XCTAssertTrue(renderer.hdrConfiguration.isHDR, "Should switch to HDR after 5 consecutive frames")
        XCTAssertEqual(renderer.hdrConfiguration.colorSpace, .bt2020)
    }
    
    // MARK: - IT-011.3: HDR to SDR Transition
    
    /// @verifies AC-083
    /// @testcase IT-011.3
    func testHDRToSDRTransitionWithJitterSuppression() {
        // 1. Enter HDR mode
        submitFrames(count: 5, format: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange)
        XCTAssertTrue(renderer.hdrConfiguration.isHDR)
        
        // 2. Submit 4 SDR frames (NV12) - should NOT switch back yet
        submitFrames(count: 4, format: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        XCTAssertTrue(renderer.hdrConfiguration.isHDR, "Should NOT switch to SDR after 4 frames")
        
        // 3. Submit 5th SDR frame - should switch back to SDR
        submitFrames(count: 1, format: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        XCTAssertFalse(renderer.hdrConfiguration.isHDR, "Should switch to SDR after 5 consecutive frames")
        XCTAssertEqual(renderer.hdrConfiguration.colorSpace, .bt709)
    }
    
    // MARK: - IT-011.4: Jitter Resistance
    
    /// @verifies AC-083
    /// @testcase IT-011.4
    func testJitterResistance() {
        // Start in SDR
        XCTAssertFalse(renderer.hdrConfiguration.isHDR)
        
        // Submit: HDR, HDR, SDR, HDR, HDR (Alternating)
        submitFrames(count: 2, format: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange)
        submitFrames(count: 1, format: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        submitFrames(count: 2, format: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange)
        
        XCTAssertFalse(renderer.hdrConfiguration.isHDR, "Intermittent SDR frames should prevent HDR switch")
        
        // Now submit 5 consecutive HDR frames
        submitFrames(count: 5, format: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange)
        XCTAssertTrue(renderer.hdrConfiguration.isHDR)
        
        // Submit 1 SDR frame (jitter)
        submitFrames(count: 1, format: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        XCTAssertTrue(renderer.hdrConfiguration.isHDR, "Single SDR jitter should not drop HDR mode")
    }
}
