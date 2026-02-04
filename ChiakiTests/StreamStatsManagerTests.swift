// SPDX-License-Identifier: AGPL-3.0-only
//
//  StreamStatsManagerTests.swift
//  ChiakiTests
//
//  Unit tests for StreamStatsManager performance metrics extension (UT-031)
//

import Testing
import Foundation
@testable import Chiaki

@MainActor
struct StreamStatsManagerTests {

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
}
