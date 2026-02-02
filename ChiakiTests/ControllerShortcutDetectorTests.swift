// SPDX-License-Identifier: AGPL-3.0-only
//
// ControllerShortcutDetectorTests.swift
// ChiakiTests
//
// Tests for controller shortcut detection (TDD - Test First)

import Testing
import Foundation
@testable import Chiaki

/**
 * @requirement F-020 - 手柄操作友好化
 * @satisfies AC-059 - 手柄组合键快捷操作
 * Note: Tests may show flaky results when run with parallel testing across multiple hosts.
 * All tests pass reliably with -parallel-testing-enabled NO.
 */
@Suite("Controller Shortcut Detector Tests", .serialized)
@MainActor
struct ControllerShortcutDetectorTests {

    /**
     * @verifies AC-059 - 手柄组合键快捷操作
     * @testcase UT-012.1
     */
    @Test func testMenuShortcutDetection() async {
        let detector = ControllerShortcutDetector()
        var menuTriggered = false

        detector.onMenuShortcut = { menuTriggered = true }

        // Press PS + Options
        detector.updateButtons([.ps, .options])

        #expect(menuTriggered == true, "PS + Options should trigger menu shortcut")
    }

    /**
     * @verifies AC-059 - 手柄组合键快捷操作
     * @testcase UT-012.2
     */
    @Test func testDisconnectShortcutDetection() async {
        let detector = ControllerShortcutDetector()
        var disconnectTriggered = false

        detector.onDisconnectShortcut = { disconnectTriggered = true }

        // Press L1 + R1 + PS
        detector.updateButtons([.l1, .r1, .ps])

        #expect(disconnectTriggered == true, "L1 + R1 + PS should trigger disconnect shortcut")
    }

    /**
     * @verifies AC-059 - 手柄组合键快捷操作
     * @testcase UT-012.3
     */
    @Test func testDebounceInterval() async throws {
        let detector = ControllerShortcutDetector()
        var triggerCount = 0

        detector.onMenuShortcut = { triggerCount += 1 }

        // First press
        detector.updateButtons([.ps, .options])
        #expect(triggerCount == 1, "First press should trigger")

        // Immediately release and press again (should be debounced)
        detector.updateButtons([])
        detector.updateButtons([.ps, .options])
        #expect(triggerCount == 1, "Should still be 1 due to debounce")

        // Wait longer than debounce interval (200ms)
        try await Task.sleep(for: .milliseconds(250))

        // Press again
        detector.updateButtons([])
        detector.updateButtons([.ps, .options])
        #expect(triggerCount == 2, "Should trigger after debounce period")
    }

    /**
     * @verifies AC-059 - 手柄组合键快捷操作
     * @testcase UT-012.4
     */
    @Test func testPartialCombinationIgnored() {
        let detector = ControllerShortcutDetector()
        var anyTriggered = false

        detector.onMenuShortcut = { anyTriggered = true }
        detector.onDisconnectShortcut = { anyTriggered = true }

        // Only press PS key
        detector.updateButtons([.ps])

        #expect(anyTriggered == false, "Single key should not trigger any shortcut")

        // Only press Options key
        detector.updateButtons([.options])

        #expect(anyTriggered == false, "Single key should not trigger any shortcut")

        // Only press L1 + R1 (without PS)
        detector.updateButtons([.l1, .r1])

        #expect(anyTriggered == false, "Partial combination should not trigger")
    }

    /**
     * @verifies AC-059 - 手柄组合键快捷操作
     * @testcase UT-012.5
     */
    @Test func testCombinationOrderIndependent() async throws {
        let detector = ControllerShortcutDetector()
        var menuCount = 0

        detector.onMenuShortcut = { menuCount += 1 }

        // Press PS first, then Options
        detector.updateButtons([.ps])
        detector.updateButtons([.ps, .options])
        #expect(menuCount == 1, "Should trigger when completing combination")

        // Wait for debounce
        try await Task.sleep(for: .milliseconds(250))
        detector.updateButtons([])

        // Press Options first, then PS
        detector.updateButtons([.options])
        detector.updateButtons([.ps, .options])
        #expect(menuCount == 2, "Order should not matter")
    }

    /**
     * @verifies AC-059 - 手柄组合键快捷操作
     * @testcase UT-012.6
     */
    @Test func testContinuousHoldNoRetrigger() {
        let detector = ControllerShortcutDetector()
        detector.reset() // Ensure clean state
        var triggerCount = 0

        detector.onMenuShortcut = { triggerCount += 1 }

        // First update with no buttons to establish baseline
        detector.updateButtons([])
        // Press and hold
        detector.updateButtons([.ps, .options])
        #expect(triggerCount == 1, "First press should trigger")

        // Continue holding (multiple updates with same state)
        detector.updateButtons([.ps, .options])
        detector.updateButtons([.ps, .options])
        detector.updateButtons([.ps, .options])

        // Should still only be triggered once
        #expect(triggerCount == 1, "Continuous hold should not retrigger")
    }

    /**
     * @verifies AC-059 - 手柄组合键快捷操作
     * @testcase UT-012.3 (debounce interval value)
     */
    @Test func testDebounceIntervalValue() {
        #expect(ControllerShortcutDetector.debounceInterval == 0.2, "Debounce interval should be 200ms")
    }
}
