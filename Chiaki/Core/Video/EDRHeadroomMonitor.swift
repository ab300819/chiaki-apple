// SPDX-License-Identifier: AGPL-3.0-only
//
// EDRHeadroomMonitor.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Dynamic monitoring of screen EDR headroom for macOS and iOS.
//
// @requirement F-025 - HDR 渲染管线优化
// @satisfies AC-081 - 动态 EDR Headroom
//

import Foundation
import QuartzCore

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Helper class to hold resources that need cleanup in deinit
/// Separated from @Observable class to avoid nonisolated(unsafe) warnings
private final class EDRMonitorResources: @unchecked Sendable {
    var displayLink: CADisplayLink?
    var observation: NSKeyValueObservation?

    deinit {
        // Invalidation is thread-safe and can be called from deinit
        displayLink?.invalidate()
        observation?.invalidate()
    }
}

/// Dynamic EDR headroom monitor
/// Provides real-time headroom information for HDR rendering adjustment
/// - Note: This class is designed for main-thread use only. All property updates occur on MainActor.
/// @satisfies AC-081
@Observable
@MainActor
final class EDRHeadroomMonitor {

    // MARK: - Properties

    /// Current smoothed EDR headroom (1.0 = SDR, > 1.0 = HDR capable)
    /// @satisfies AC-081
    private(set) var currentHeadroom: Float = 1.0

    /// Maximum observed headroom for the current session
    /// @satisfies AC-081
    private(set) var maxHeadroom: Float = 1.0

    /// Resources holder for deinit cleanup
    private let resources = EDRMonitorResources()

    // MARK: - Initialization

    init() {
        startMonitoring()
    }

    // MARK: - Private Methods

    private func startMonitoring() {
        #if os(macOS)
        // macOS: Observe NSScreen.maximumExtendedDynamicRangeColorComponentValue
        resources.observation = NSScreen.main?.observe(\.maximumExtendedDynamicRangeColorComponentValue, options: [.initial, .new]) { [weak self] screen, _ in
            let value = Float(screen.maximumExtendedDynamicRangeColorComponentValue)
            Task { @MainActor [weak self] in
                self?.updateHeadroom(value)
            }
        }
        #else
        // iOS 16+: Use UIScreen.currentEDRHeadroom via CADisplayLink
        if #available(iOS 16.0, tvOS 16.0, *) {
            resources.displayLink = CADisplayLink(target: self, selector: #selector(updateFromDisplayLink))
            // Limit update frequency to conserve power (5Hz is enough for headroom changes)
            resources.displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 1, maximum: 10, preferred: 5)
            resources.displayLink?.add(to: .main, forMode: .common)
        }
        #endif
    }

    @objc private func updateFromDisplayLink() {
        #if os(iOS) || os(tvOS)
        if #available(iOS 16.0, tvOS 16.0, *) {
            updateHeadroom(Float(UIScreen.main.currentEDRHeadroom))
        }
        #endif
    }

    /// Updates the headroom values with smoothing logic
    /// - Parameter value: The raw headroom value from the system
    /// @satisfies AC-081
    private func updateHeadroom(_ value: Float) {
        // Validation: Ensure value is sane
        let saneValue = max(1.0, value)

        // Smoothing logic: currentHeadroom * 0.9 + value * 0.1
        // Prevents sudden brightness spikes when ambient light changes or screen dims
        let smoothed = currentHeadroom * 0.9 + saneValue * 0.1

        currentHeadroom = smoothed
        maxHeadroom = max(maxHeadroom, saneValue)
    }
}
