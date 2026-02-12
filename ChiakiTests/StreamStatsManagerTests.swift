// SPDX-License-Identifier: AGPL-3.0-only
//
//  StreamStatsManagerTests.swift
//  ChiakiTests
//
//  Unit tests for StreamStatsManager performance metrics extension (UT-031)
//

import Testing
import Foundation
import MetalKit
import CoreVideo
@testable import Chiaki

@MainActor
struct StreamStatsManagerTests {

    private final class DummyDiagnosticsRenderer: VideoRenderer, RenderDiagnosticsReporting, @unchecked Sendable {
        weak var mtkView: MTKView?
        var displayMode: VideoDisplayMode = .normal
        var zoomFactor: Float = 1.0
        var vrrEnabled: Bool = false
        var hdrConfiguration: HDRConfiguration = .sdr
        var edrHeadroom: Float = 1.0
        var filterConfig: VideoFilterConfig = .default
        var frameSize: CGSize = .zero
        var hasFrame: Bool = false
        var frameCount: UInt64 = 0
        var droppedFrameCount: UInt64 = 7
        var frameRepeatCount: UInt64 = 3
        var presentInterval: Double = 16.7
        var filterName: String = "libplacebo"
        var backendName: String = "libplacebo"
        var onFrameSubmitted: ((CVPixelBuffer) -> Void)?
        var onRenderTimeRecorded: ((Double) -> Void)?

        func submitFrame(_ pixelBuffer: CVPixelBuffer) {}
        func setFilterConfig(_ config: VideoFilterConfig) {}
        func setBrightness(_ value: Float) {}
        func setContrast(_ value: Float) {}
        func setSaturation(_ value: Float) {}
        func setColorSpace(_ value: UInt32) {}
        func updateRenderingPolicy(fps: Int?) {}
        func updateViewSize(_ size: CGSize) {}
        func flushTextureCache() {}
        func render(to view: MTKView, descriptor: MTLRenderPassDescriptor?) {}
        func resetStatistics() {}
    }

    /**
     * @verifies AC-039 - 架构解耦：提取统计管理模块
     * @testcase UT-11.1
     */
    @Test func testStatsUpdateFromSession() {
        let stats = StreamStatistics()
        let manager = StreamStatsManager(statistics: stats)
        
        #expect(manager.bitrate == 0)
        #expect(manager.latency == 0)
    }

    /**
     * @verifies AC-085 - 渲染性能指标扩展
     * @testcase UT-031.1
     */
    @Test func testPerformanceRecording() {
        let stats = StreamStatistics()
        let manager = StreamStatsManager(statistics: stats)
        
        manager.recordDecodeTime(12.5)
        #expect(manager.decodeTimeMs == 12.5)
        
        manager.recordRenderTime(8.2)
        #expect(manager.renderTimeMs == 8.2)
    }

    /**
     * @verifies AC-085 - 百分位计算
     * @testcase UT-031.2
     */
    @Test func testLatencyPercentiles() {
        let stats = StreamStatistics()
        let manager = StreamStatsManager(statistics: stats)
        
        // Submit 100 samples from 1 to 100
        for i in 1...100 {
            manager.addLatencySample(Double(i))
        }
        
        // P95 of [1...100] should be 96 (index 95 in 0-based sorted array)
        #expect(manager.p95LatencyMs == 96.0)
        
        // P99 of [1...100] should be 100 (index 99 in 0-based sorted array)
        #expect(manager.p99LatencyMs == 100.0)
        
        #expect(manager.p99LatencyMs >= manager.p95LatencyMs)
    }

    /**
     * @verifies AC-187
     * @testcase UT-065.3
     */
    @Test func testRendererDiagnosticsIncludeBackendName() {
        let stats = StreamStatistics()
        let manager = StreamStatsManager(statistics: stats)
        let renderer = DummyDiagnosticsRenderer()
        manager.videoRenderer = renderer

        manager.update()

        #expect(manager.renderBackend == "libplacebo")
        #expect(manager.currentFilter == "libplacebo")
        #expect(manager.rendererDropCount == 7)
        #expect(manager.frameRepeatCount == 3)
        #expect(manager.presentInterval == 16.7)
    }
}
