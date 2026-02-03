// SPDX-License-Identifier: AGPL-3.0-only
//
// VirtualButtonLongPressTests.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Unit tests for VirtualButtonView long press gesture support
// @verifies AC-074 - 长按手势支持
// @testcase UT-023.1~7

import Testing
import CoreGraphics
@testable import Chiaki

@Suite("VirtualButtonLongPress Tests")
struct VirtualButtonLongPressTests {

    // MARK: - Configuration Tests

    /// @verifies AC-074 - Long press threshold is 0.5 seconds
    /// @testcase UT-023.1
    @Test("Long press duration threshold is 0.5 seconds")
    func testLongPressDuration() {
        #expect(VirtualButtonConfig.longPressDuration == 0.5)
    }

    /// @verifies AC-074 - Long press scale effect
    /// @testcase UT-023.2
    @Test("Long press scale effect is 0.85")
    func testLongPressScale() {
        #expect(VirtualButtonConfig.longPressScale == 0.85)
    }

    /// @verifies AC-074 - Long press scale is smaller than tap scale
    /// @testcase UT-023.3
    @Test("Long press scale is smaller than tap scale for visual feedback")
    func testLongPressScaleSmallerThanTapScale() {
        let tapScale: CGFloat = 0.92
        #expect(VirtualButtonConfig.longPressScale < tapScale)
    }

    // MARK: - Duration Threshold Tests

    /// @verifies AC-074 - Duration threshold is positive
    /// @testcase UT-023.4
    @Test("Long press duration is a positive value")
    func testLongPressDurationPositive() {
        #expect(VirtualButtonConfig.longPressDuration > 0)
    }

    /// @verifies AC-074 - Duration threshold is reasonable (not too long)
    /// @testcase UT-023.5
    @Test("Long press duration is reasonable (under 1 second)")
    func testLongPressDurationReasonable() {
        #expect(VirtualButtonConfig.longPressDuration < 1.0)
    }

    // MARK: - Scale Effect Tests

    /// @verifies AC-074 - Scale effect is visible (not too small)
    /// @testcase UT-023.6
    @Test("Long press scale is visible (above 0.5)")
    func testLongPressScaleVisible() {
        #expect(VirtualButtonConfig.longPressScale > 0.5)
    }

    /// @verifies AC-074 - Scale effect is subtle (not too dramatic)
    /// @testcase UT-023.7
    @Test("Long press scale is subtle (below 1.0)")
    func testLongPressScaleSubtle() {
        #expect(VirtualButtonConfig.longPressScale < 1.0)
    }
}
