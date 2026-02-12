// SPDX-License-Identifier: AGPL-3.0-only
//
// StreamStatsManager.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Manager for stream statistics, decoupled from StreamingViewModel
//

import Foundation
import Observation

/**
 * 串流统计管理器
 * @requirement F-012 - 架构解耦与重构
 * @satisfies AC-039 - 提取统计管理模块
 */
@Observable
@MainActor
final class StreamStatsManager {
    // MARK: - Properties
    
    var currentResolution: String = "1080p"
    var currentFrameRate: Double = 0
    var latency: Double = 0
    var bitrate: Double = 0
    var packetLoss: Double = 0
    var droppedFrames: Int = 0
    var recoveredFrames: Int = 0
    var isPoorConnection: Bool = false
    var connectionQuality: ConnectionQuality = .unknown
    var isHDR: Bool = false
    
    // MARK: - Performance Metrics
    // [requirement] F-025
    // [satisfies] AC-085
    var decodeTimeMs: Double = 0
    var renderTimeMs: Double = 0
    var p95LatencyMs: Double = 0
    var p99LatencyMs: Double = 0
    
    // MARK: - Render Pipeline Diagnostics
    // @requirement F-041
    // @satisfies AC-166
    var rendererDropCount: UInt64 = 0
    var frameRepeatCount: UInt64 = 0
    var presentInterval: Double = 0
    var currentFilter: String = "Bicubic"
    var renderBackend: String = "Metal Native"

    // MARK: - Private Storage

    private var latencySamples: [Double] = []
    private let maxSampleSize = 100
    
    // MARK: - Dependencies

    private let statistics: StreamStatistics
    private let session: ChiakiSessionWrapper?
    /// Weak reference to the video renderer for pulling diagnostics
    weak var videoRenderer: (any VideoRenderer)?

    // MARK: - Initialization

    init(statistics: StreamStatistics, session: ChiakiSessionWrapper? = nil) {
        self.statistics = statistics
        self.session = session
    }
    
    // MARK: - Update
    
    /**
     * 更新统计数据
     * @satisfies AC-039
     */
    func update() {
        session?.updateStatistics()
        
        currentFrameRate = statistics.currentFrameRate
        latency = statistics.networkLatency
        
        // [satisfies] AC-085
        updateLatencyPercentiles(currentLatency: latency)
        
        // Use libchiaki bitrate if available, fallback to measured bitrate
        if statistics.libchiakiBitrate > 0 {
            bitrate = statistics.libchiakiBitrate
        } else {
            bitrate = statistics.measuredBitrate
        }
        
        packetLoss = statistics.packetLossPercentage
        droppedFrames = Int(statistics.totalDroppedFrames)
        recoveredFrames = Int(statistics.recoveredFrames)
        connectionQuality = statistics.connectionQuality
        
        isPoorConnection = packetLoss > 5.0
        currentResolution = "1080p" // TODO: Get from session

        let newIsHDR = session?.isHDR ?? false
        if newIsHDR != isHDR {
            logInfo("StreamStatsManager: isHDR changed from \(isHDR) to \(newIsHDR)")
        }
        isHDR = newIsHDR

        // Render pipeline diagnostics [satisfies] AC-166
        if let renderer = videoRenderer as? RenderDiagnosticsReporting {
            rendererDropCount = renderer.droppedFrameCount
            frameRepeatCount = renderer.frameRepeatCount
            presentInterval = renderer.presentInterval
            currentFilter = renderer.filterName
            renderBackend = renderer.backendName
        }
    }
    
    // MARK: - Performance Recording
    
    /**
     * 记录解码耗时
     * @satisfies AC-085
     */
    func recordDecodeTime(_ timeMs: Double) {
        decodeTimeMs = timeMs
    }
    
    /**
     * 记录渲染耗时
     * @satisfies AC-085
     */
    func recordRenderTime(_ timeMs: Double) {
        renderTimeMs = timeMs
    }

    /**
     * 手动添加延迟样本（主要用于测试或非标准延迟统计）
     * @satisfies AC-085
     */
    func addLatencySample(_ sample: Double) {
        updateLatencyPercentiles(currentLatency: sample)
    }
    
    // MARK: - Private Helpers
    
    private func updateLatencyPercentiles(currentLatency: Double) {
        // Skip zero samples (initial state)
        guard currentLatency > 0 else { return }
        
        latencySamples.append(currentLatency)
        if latencySamples.count > maxSampleSize {
            latencySamples.removeFirst()
        }
        
        let sorted = latencySamples.sorted()
        let count = sorted.count
        
        if count > 0 {
            // P95 calculation: Take the value at the 95th percentile index
            let p95Index = min(count - 1, Int(Double(count) * 0.95))
            p95LatencyMs = sorted[p95Index]
            
            // P99 calculation: Take the value at the 99th percentile index
            let p99Index = min(count - 1, Int(Double(count) * 0.99))
            p99LatencyMs = sorted[p99Index]
        }
    }
}
