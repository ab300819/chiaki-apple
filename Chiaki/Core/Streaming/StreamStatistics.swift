// SPDX-License-Identifier: AGPL-3.0-only
//
// StreamStatistics.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Stream statistics tracking for video, audio, and network metrics
// Design based on chiaki-ng/gui StreamView.qml statistics display

import Foundation

// MARK: - Stream Statistics

/// Observable stream statistics for UI display
/// Tracks video bitrate, frame drops, packet loss, and audio underruns
@Observable
final class StreamStatistics {
    // MARK: - Video Statistics

    /// Measured video bitrate (Mbps)
    private(set) var measuredBitrate: Double = 0

    /// Dropped frame count (decoder couldn't keep up)
    private(set) var droppedFrames: UInt64 = 0

    /// Successfully decoded frame count
    private(set) var decodedFrames: UInt64 = 0

    /// Current video frame rate (fps)
    private(set) var currentFrameRate: Double = 0

    // MARK: - Network Statistics

    /// Average packet loss rate (0.0 - 1.0)
    private(set) var averagePacketLoss: Double = 0

    /// Network round-trip latency (ms)
    private(set) var networkLatency: Double = 0

    /// Packets received count
    private(set) var packetsReceived: UInt64 = 0

    /// Packets lost count
    private(set) var packetsLost: UInt64 = 0

    // MARK: - Audio Statistics

    /// Audio buffer underrun count (audio renderer ran out of data)
    private(set) var audioUnderruns: UInt64 = 0

    /// Audio buffer fill ratio (0.0 - 1.0)
    private(set) var audioBufferFill: Double = 0

    // MARK: - Session Statistics

    /// Session start time
    private(set) var sessionStartTime: Date?

    /// Total bytes received
    private(set) var totalBytesReceived: UInt64 = 0

    // MARK: - Internal State

    private var packetLossHistory: [Double] = []
    private let maxHistorySize = 100

    private var lastBitrateUpdate = Date()
    private var bytesReceivedSinceLastUpdate: UInt64 = 0

    private var lastFrameRateUpdate = Date()
    private var framesSinceLastUpdate: UInt64 = 0

    private let lock = NSLock()

    // MARK: - Initialization

    init() {
        logInfo("StreamStatistics: Initialized")
    }

    // MARK: - Recording Methods

    /// Record a received video frame
    /// - Parameters:
    ///   - size: Frame size in bytes
    ///   - wasDropped: Whether frame was dropped
    func recordVideoFrame(size: Int, wasDropped: Bool) {
        lock.lock()
        defer { lock.unlock() }

        if wasDropped {
            droppedFrames += 1
        } else {
            decodedFrames += 1
            framesSinceLastUpdate += 1
        }

        bytesReceivedSinceLastUpdate += UInt64(size)
        totalBytesReceived += UInt64(size)

        updateBitrate()
        updateFrameRate()
    }

    /// Record packet loss event
    /// - Parameter lossRate: Current loss rate (0.0 - 1.0)
    func recordPacketLoss(_ lossRate: Double) {
        lock.lock()
        defer { lock.unlock() }

        packetLossHistory.append(lossRate)
        if packetLossHistory.count > maxHistorySize {
            packetLossHistory.removeFirst()
        }
        averagePacketLoss = packetLossHistory.reduce(0, +) / Double(packetLossHistory.count)
    }

    /// Record packet statistics
    /// - Parameters:
    ///   - received: Total packets received
    ///   - lost: Total packets lost
    func recordPacketStats(received: UInt64, lost: UInt64) {
        lock.lock()
        defer { lock.unlock() }

        packetsReceived = received
        packetsLost = lost

        if received > 0 {
            let lossRate = Double(lost) / Double(received + lost)
            recordPacketLossUnlocked(lossRate)
        }
    }

    /// Record audio buffer underrun
    func recordAudioUnderrun() {
        lock.lock()
        defer { lock.unlock() }

        audioUnderruns += 1
    }

    /// Update audio buffer fill level
    /// - Parameter fillRatio: Buffer fill ratio (0.0 - 1.0)
    func updateAudioBufferFill(_ fillRatio: Double) {
        lock.lock()
        defer { lock.unlock() }

        audioBufferFill = fillRatio
    }

    /// Update network latency
    /// - Parameter latency: Round-trip latency in milliseconds
    func updateLatency(_ latency: Double) {
        lock.lock()
        defer { lock.unlock() }

        networkLatency = latency
    }

    /// Mark session start
    func sessionStarted() {
        lock.lock()
        defer { lock.unlock() }

        sessionStartTime = Date()
        reset()
    }

    /// Mark session end
    func sessionEnded() {
        lock.lock()
        defer { lock.unlock() }

        logInfo("StreamStatistics: Session ended - " +
                "Decoded: \(decodedFrames), Dropped: \(droppedFrames), " +
                "Packet Loss: \(String(format: "%.2f", averagePacketLoss * 100))%, " +
                "Audio Underruns: \(audioUnderruns)")
    }

    /// Reset all statistics
    func reset() {
        measuredBitrate = 0
        droppedFrames = 0
        decodedFrames = 0
        currentFrameRate = 0
        averagePacketLoss = 0
        networkLatency = 0
        packetsReceived = 0
        packetsLost = 0
        audioUnderruns = 0
        audioBufferFill = 0
        totalBytesReceived = 0
        packetLossHistory.removeAll()
        bytesReceivedSinceLastUpdate = 0
        framesSinceLastUpdate = 0
        lastBitrateUpdate = Date()
        lastFrameRateUpdate = Date()

        logInfo("StreamStatistics: Reset")
    }

    // MARK: - Computed Properties

    /// Session duration in seconds
    var sessionDuration: TimeInterval {
        guard let start = sessionStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    /// Formatted session duration string (HH:MM:SS)
    var formattedDuration: String {
        let duration = Int(sessionDuration)
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        let seconds = duration % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    /// Frame drop rate (0.0 - 1.0)
    var frameDropRate: Double {
        let total = decodedFrames + droppedFrames
        guard total > 0 else { return 0 }
        return Double(droppedFrames) / Double(total)
    }

    /// Connection quality indicator
    var connectionQuality: ConnectionQuality {
        // Determine quality based on metrics
        if averagePacketLoss > 0.1 || networkLatency > 100 {
            return .poor
        } else if averagePacketLoss > 0.02 || networkLatency > 50 {
            return .fair
        } else if averagePacketLoss > 0.005 || networkLatency > 30 {
            return .good
        } else {
            return .excellent
        }
    }

    // MARK: - Private Methods

    private func updateBitrate() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastBitrateUpdate)

        if elapsed >= 1.0 {
            // Calculate Mbps: bytes * 8 / seconds / 1,000,000
            measuredBitrate = Double(bytesReceivedSinceLastUpdate) * 8.0 / elapsed / 1_000_000.0
            bytesReceivedSinceLastUpdate = 0
            lastBitrateUpdate = now
        }
    }

    private func updateFrameRate() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastFrameRateUpdate)

        if elapsed >= 1.0 {
            currentFrameRate = Double(framesSinceLastUpdate) / elapsed
            framesSinceLastUpdate = 0
            lastFrameRateUpdate = now
        }
    }

    private func recordPacketLossUnlocked(_ lossRate: Double) {
        packetLossHistory.append(lossRate)
        if packetLossHistory.count > maxHistorySize {
            packetLossHistory.removeFirst()
        }
        averagePacketLoss = packetLossHistory.reduce(0, +) / Double(packetLossHistory.count)
    }
}

// MARK: - Connection Quality

/// Connection quality indicator
enum ConnectionQuality: String, CaseIterable {
    case unknown = "Unknown"
    case poor = "Poor"
    case fair = "Fair"
    case good = "Good"
    case excellent = "Excellent"

    /// Color for UI display
    var displayColor: String {
        switch self {
        case .unknown: return "gray"
        case .poor: return "red"
        case .fair: return "orange"
        case .good: return "yellow"
        case .excellent: return "green"
        }
    }

    /// Symbol for UI display
    var symbol: String {
        switch self {
        case .unknown: return "wifi.slash"
        case .poor: return "wifi.exclamationmark"
        case .fair: return "wifi"
        case .good: return "wifi"
        case .excellent: return "wifi"
        }
    }

    /// Number of bars to show (0-4)
    var signalBars: Int {
        switch self {
        case .unknown: return 0
        case .poor: return 1
        case .fair: return 2
        case .good: return 3
        case .excellent: return 4
        }
    }
}

// MARK: - Statistics Summary

extension StreamStatistics {
    /// Generate a summary dictionary for logging/debugging
    var summary: [String: Any] {
        [
            "bitrate_mbps": String(format: "%.2f", measuredBitrate),
            "frame_rate": String(format: "%.1f", currentFrameRate),
            "decoded_frames": decodedFrames,
            "dropped_frames": droppedFrames,
            "drop_rate": String(format: "%.2f%%", frameDropRate * 100),
            "packet_loss": String(format: "%.2f%%", averagePacketLoss * 100),
            "latency_ms": String(format: "%.1f", networkLatency),
            "audio_underruns": audioUnderruns,
            "connection_quality": connectionQuality.rawValue
        ]
    }
}
