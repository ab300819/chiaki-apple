// SPDX-License-Identifier: AGPL-3.0-only
//
// HDRMetadataCache.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// HDR metadata cache with jitter suppression to avoid frequent pipeline switching.
//
// @requirement F-025 - HDR 渲染管线优化
// @satisfies AC-083 - 元数据抖动抑制
//

import Foundation

/// HDR metadata cache for jitter suppression
/// Confirms HDR or SDR state only after a consecutive number of frames
/// - Note: This class is not thread-safe. External synchronization required (e.g., MetalVideoRenderer.frameLock)
/// @satisfies AC-083
final class HDRMetadataCache {

    // MARK: - Properties

    /// Currently confirmed HDR status
    /// Initial state is SDR (false) as per requirement
    private(set) var confirmedHDR: Bool = false

    /// HDR detection counter (consecutive HDR frames)
    private var hdrDetectionCount: Int = 0

    /// SDR detection counter (consecutive SDR frames)
    private var sdrDetectionCount: Int = 0

    /// Threshold for confirming a state change (consecutive frames)
    private let confirmationThreshold = 5

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Updates the detection state based on the current frame's metadata
    /// - Parameter isHDRFrame: Whether the current frame is detected as HDR
    /// - Returns: The confirmed HDR state after applying jitter suppression
    /// @satisfies AC-083
    @discardableResult
    func update(isHDRFrame: Bool) -> Bool {
        if isHDRFrame {
            hdrDetectionCount += 1
            sdrDetectionCount = 0
            if hdrDetectionCount >= confirmationThreshold {
                confirmedHDR = true
            }
        } else {
            sdrDetectionCount += 1
            hdrDetectionCount = 0
            if sdrDetectionCount >= confirmationThreshold {
                confirmedHDR = false
            }
        }
        return confirmedHDR
    }

    /// Resets the cache state to initial SDR mode
    /// @satisfies AC-083
    func reset() {
        confirmedHDR = false
        hdrDetectionCount = 0
        sdrDetectionCount = 0
    }
}
