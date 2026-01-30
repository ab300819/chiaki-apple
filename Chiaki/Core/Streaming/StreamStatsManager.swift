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
    
    // MARK: - Dependencies
    
    private let statistics: StreamStatistics
    private let session: ChiakiSessionWrapper?
    
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
        isHDR = session?.isHDR ?? false
    }
}
