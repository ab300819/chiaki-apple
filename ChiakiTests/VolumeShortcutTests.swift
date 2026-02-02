// SPDX-License-Identifier: AGPL-3.0-only
//
// VolumeShortcutTests.swift
// ChiakiTests
//
// Tests for volume shortcut detection in ControllerShortcutDetector

import Testing
import Foundation
@testable import Chiaki

/**
 * Volume Shortcut Tests
 * @verifies AC-066 - 流媒体中音量快捷调节
 * Note: Tests may show flaky results when run with parallel testing across multiple hosts.
 * All tests pass reliably with -parallel-testing-enabled NO.
 */
@Suite("Volume Shortcut Tests", .serialized)
@MainActor
struct VolumeShortcutTests {

    // MARK: - UT-018.1: PS + R2 Volume Up Detection

    /**
     * @verifies AC-066 - PS + R2 检测
     * @testcase UT-018.1
     */
    @Test("PS + R2 triggers volume up")
    func testVolumeUpShortcutDetection() {
        let detector = ControllerShortcutDetector()
        detector.reset() // Ensure clean state
        var volumeUpCalled = false
        detector.onVolumeUp = { volumeUpCalled = true }

        // First update with no buttons to establish baseline
        detector.updateButtons([])
        // Then press PS + R2
        detector.updateButtons([.ps, .r2])

        #expect(volumeUpCalled == true)
    }

    // MARK: - UT-018.2: PS + L2 Volume Down Detection

    /**
     * @verifies AC-066 - PS + L2 检测
     * @testcase UT-018.2
     */
    @Test("PS + L2 triggers volume down")
    func testVolumeDownShortcutDetection() {
        let detector = ControllerShortcutDetector()
        detector.reset() // Ensure clean state
        var volumeDownCalled = false
        detector.onVolumeDown = { volumeDownCalled = true }

        // First update with no buttons to establish baseline
        detector.updateButtons([])
        // Then press PS + L2
        detector.updateButtons([.ps, .l2])

        #expect(volumeDownCalled == true)
    }

    // MARK: - UT-018.3: 200ms Throttle Interval

    /**
     * @verifies AC-066 - 200ms 节流
     * @testcase UT-018.3
     */
    @Test("Volume shortcuts throttled at 200ms")
    func testVolumeThrottleInterval() async throws {
        let detector = ControllerShortcutDetector()
        detector.reset() // Ensure clean state
        var callCount = 0
        detector.onVolumeUp = { callCount += 1 }

        // First trigger
        detector.updateButtons([])
        detector.updateButtons([.ps, .r2])
        #expect(callCount == 1)

        // Release and immediately re-trigger (should be throttled)
        detector.updateButtons([])
        detector.updateButtons([.ps, .r2])
        #expect(callCount == 1) // Should still be 1 due to throttle

        // Wait for throttle to expire (250ms > 200ms)
        try await Task.sleep(for: .milliseconds(250))

        // Trigger again after throttle expired
        detector.updateButtons([])
        detector.updateButtons([.ps, .r2])
        #expect(callCount == 2) // Should succeed now
    }

    // MARK: - UT-018.4: Volume Adjustment Step

    /**
     * @verifies AC-066 - 音量调节步长
     * @testcase UT-018.4
     */
    @Test("Volume adjustment step is 5%")
    func testVolumeAdjustmentStep() {
        // Test the volume step constant
        #expect(VolumeAdjuster.volumeStep == 0.05)

        // Test volume increase
        let increased = VolumeAdjuster.adjustVolume(0.5, direction: .up)
        #expect(increased == 0.55)

        // Test volume decrease
        let decreased = VolumeAdjuster.adjustVolume(0.5, direction: .down)
        #expect(decreased == 0.45)
    }

    // MARK: - UT-018.5: Volume Clamp to Min/Max

    /**
     * @verifies AC-066 - 音量范围限制
     * @testcase UT-018.5
     */
    @Test("Volume clamped to 0.0-1.0 range")
    func testVolumeClampToMinMax() {
        // Test upper bound - should not exceed 1.0
        let atMax = VolumeAdjuster.adjustVolume(0.98, direction: .up)
        #expect(atMax == 1.0)

        // Test lower bound - should not go below 0.0
        let atMin = VolumeAdjuster.adjustVolume(0.02, direction: .down)
        #expect(atMin == 0.0)

        // Test exact boundary
        let exactMax = VolumeAdjuster.adjustVolume(1.0, direction: .up)
        #expect(exactMax == 1.0)

        let exactMin = VolumeAdjuster.adjustVolume(0.0, direction: .down)
        #expect(exactMin == 0.0)
    }

    // MARK: - UT-018.6: Concurrent L2+R2 Ignored

    /**
     * @verifies AC-066 - 同时按 L2+R2 不触发
     * @testcase UT-018.6
     */
    @Test("Concurrent L2+R2 ignored (conflict protection)")
    func testConcurrentL2R2Ignored() {
        let detector = ControllerShortcutDetector()
        detector.reset() // Ensure clean state
        var upCalled = false
        var downCalled = false
        detector.onVolumeUp = { upCalled = true }
        detector.onVolumeDown = { downCalled = true }

        // First update with no buttons to establish baseline
        detector.updateButtons([])
        // Press PS + L2 + R2 simultaneously
        detector.updateButtons([.ps, .l2, .r2])

        #expect(upCalled == false)
        #expect(downCalled == false)
    }

    // MARK: - Additional: Single Trigger Test

    /**
     * @verifies AC-066 - 单按 PS 或单按 L2/R2 不触发
     */
    @Test("Single button does not trigger volume shortcut")
    func testSingleButtonNoTrigger() {
        let detector = ControllerShortcutDetector()
        detector.reset() // Ensure clean state
        var upCalled = false
        var downCalled = false
        detector.onVolumeUp = { upCalled = true }
        detector.onVolumeDown = { downCalled = true }

        // Only PS
        detector.updateButtons([])
        detector.updateButtons([.ps])
        #expect(upCalled == false)
        #expect(downCalled == false)

        // Only L2
        detector.updateButtons([])
        detector.updateButtons([.l2])
        #expect(upCalled == false)
        #expect(downCalled == false)

        // Only R2
        detector.updateButtons([])
        detector.updateButtons([.r2])
        #expect(upCalled == false)
        #expect(downCalled == false)
    }

    // MARK: - Additional: Hold Does Not Repeat

    /**
     * @verifies AC-066 - 持续按住不重复触发
     */
    @Test("Holding buttons does not repeat trigger")
    func testHoldDoesNotRepeat() {
        let detector = ControllerShortcutDetector()
        detector.reset() // Ensure clean state
        var callCount = 0
        detector.onVolumeUp = { callCount += 1 }

        // First update with no buttons to establish baseline
        detector.updateButtons([])
        // Press and hold
        detector.updateButtons([.ps, .r2])
        #expect(callCount == 1)

        // Continue holding (simulated by calling updateButtons with same state)
        detector.updateButtons([.ps, .r2])
        detector.updateButtons([.ps, .r2])
        detector.updateButtons([.ps, .r2])

        #expect(callCount == 1) // Should not increase
    }
}
