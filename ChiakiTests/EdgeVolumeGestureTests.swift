// SPDX-License-Identifier: AGPL-3.0-only
//
// EdgeVolumeGestureTests.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Unit tests for edge volume gesture configuration
// @verifies AC-075 - 滑动快捷调节
// @testcase UT-024.1~7

import Testing
import CoreGraphics
@testable import Chiaki

@Suite("EdgeVolumeGesture Tests")
struct EdgeVolumeGestureTests {

    // MARK: - Edge Width Tests

    /// @verifies AC-075 - Edge detection zone width is 44pt (Apple HIG minimum)
    /// @testcase UT-024.1
    @Test("Edge detection zone width is 44pt")
    func testEdgeWidth() {
        #expect(EdgeVolumeConfig.edgeWidth == 44)
    }

    /// @verifies AC-075 - Edge width meets Apple HIG minimum touch target
    /// @testcase UT-024.2
    @Test("Edge width meets Apple HIG minimum (44pt)")
    func testEdgeWidthMeetsHIG() {
        let applehigMinimum: CGFloat = 44
        #expect(EdgeVolumeConfig.edgeWidth >= applehigMinimum)
    }

    // MARK: - Drag Distance Tests

    /// @verifies AC-075 - Minimum drag distance is reasonable
    /// @testcase UT-024.3
    @Test("Minimum drag distance is set")
    func testMinimumDragDistance() {
        #expect(EdgeVolumeConfig.minimumDragDistance > 0)
    }

    /// @verifies AC-075 - Minimum drag distance prevents accidental triggers
    /// @testcase UT-024.4
    @Test("Minimum drag distance is at least 10pt")
    func testMinimumDragDistanceReasonable() {
        #expect(EdgeVolumeConfig.minimumDragDistance >= 10)
    }

    // MARK: - Volume Sensitivity Tests

    /// @verifies AC-075 - Volume per point is positive
    /// @testcase UT-024.5
    @Test("Volume per point is positive")
    func testVolumePerPointPositive() {
        #expect(EdgeVolumeConfig.volumePerPoint > 0)
    }

    /// @verifies AC-075 - Volume sensitivity is reasonable (not too fast)
    /// @testcase UT-024.6
    @Test("Volume sensitivity is reasonable")
    func testVolumeSensitivityReasonable() {
        // At 500pt drag (a long swipe), should change volume by ~100%
        let expectedMaxChange = 500 * EdgeVolumeConfig.volumePerPoint
        #expect(expectedMaxChange >= 0.5)  // At least 50% change on long swipe
        #expect(expectedMaxChange <= 2.0)  // But not more than 200%
    }

    /// @verifies AC-075 - Small drag produces small volume change
    /// @testcase UT-024.7
    @Test("Small drag produces small volume change")
    func testSmallDragSmallChange() {
        // 50pt drag should produce ~10% volume change
        let smallDragChange = 50 * EdgeVolumeConfig.volumePerPoint
        #expect(smallDragChange <= 0.15)  // Should be 10% or less
    }
}
