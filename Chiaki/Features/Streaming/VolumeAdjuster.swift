// SPDX-License-Identifier: AGPL-3.0-only
//
// VolumeAdjuster.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Volume adjustment utilities for controller shortcuts

import Foundation

/**
 * Volume adjustment direction
 * @requirement F-022 - 手柄操控 UI/UX 优化
 * @satisfies AC-066 - 流媒体中音量快捷调节
 */
enum VolumeDirection {
    case up
    case down
}

/**
 * Volume adjustment utilities
 * @requirement F-022 - 手柄操控 UI/UX 优化
 * @satisfies AC-066 - 流媒体中音量快捷调节
 */
enum VolumeAdjuster {
    /// Volume adjustment step: 5% (0.05)
    static let volumeStep: Double = 0.05

    /**
     * Adjust volume by the standard step in the given direction
     * - Parameters:
     *   - currentVolume: Current volume level (0.0-1.0)
     *   - direction: Direction to adjust (up or down)
     * - Returns: New volume clamped to 0.0-1.0 range
     * @satisfies AC-066 - 音量调节步长为 5%，限制在 0.0~1.0 范围
     */
    static func adjustVolume(_ currentVolume: Double, direction: VolumeDirection) -> Double {
        switch direction {
        case .up:
            return min(1.0, currentVolume + volumeStep)
        case .down:
            return max(0.0, currentVolume - volumeStep)
        }
    }
}
