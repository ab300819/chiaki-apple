// SPDX-License-Identifier: AGPL-3.0-only
//
// TouchPointTests.swift
// ChiakiTests
//
// Tests for DualSense touchpad position tracking
// @verifies AC-062 - 触控板位置追踪

import Testing
@testable import Chiaki

@Suite("TouchPoint Tests")
struct TouchPointTests {

    // MARK: - UT-014.1: TouchPoint Initialization

    /**
     * @verifies AC-062
     * @testcase UT-014.1
     */
    @Test("TouchPoint initializes with correct values")
    func testTouchPointInitialization() {
        let point = TouchPoint(id: 0, x: 0.5, y: 0.75, isActive: true)

        #expect(point.id == 0)
        #expect(point.x == 0.5)
        #expect(point.y == 0.75)
        #expect(point.isActive == true)
    }

    @Test("TouchPoint initializes with id 1")
    func testTouchPointInitializationWithSecondaryId() {
        let point = TouchPoint(id: 1, x: 0.3, y: 0.4, isActive: true)

        #expect(point.id == 1)
        #expect(point.x == 0.3)
        #expect(point.y == 0.4)
        #expect(point.isActive == true)
    }

    @Test("TouchPoint initializes from raw coordinates")
    func testTouchPointInitializationFromRaw() {
        // Raw coordinates: x=960 (half of 1920), y=540 (half of 1079 ~= 0.5)
        let point = TouchPoint(id: 0, rawX: 960, rawY: 540, isActive: true)

        #expect(point.id == 0)
        #expect(point.x == 0.5) // 960 / 1920 = 0.5
        #expect(abs(point.y - 0.5) < 0.01) // 540 / 1079 ≈ 0.5
        #expect(point.isActive == true)
    }

    // MARK: - UT-014.2: TouchPoint Equatable

    /**
     * @verifies AC-062
     * @testcase UT-014.2
     */
    @Test("TouchPoint Equatable conformance")
    func testTouchPointEquatable() {
        let point1 = TouchPoint(id: 0, x: 0.5, y: 0.5, isActive: true)
        let point2 = TouchPoint(id: 0, x: 0.5, y: 0.5, isActive: true)
        let point3 = TouchPoint(id: 1, x: 0.5, y: 0.5, isActive: true)

        #expect(point1 == point2)
        #expect(point1 != point3)
    }

    @Test("TouchPoint different coordinates are not equal")
    func testTouchPointDifferentCoordinates() {
        let point1 = TouchPoint(id: 0, x: 0.5, y: 0.5, isActive: true)
        let point2 = TouchPoint(id: 0, x: 0.6, y: 0.5, isActive: true)
        let point3 = TouchPoint(id: 0, x: 0.5, y: 0.6, isActive: true)

        #expect(point1 != point2)
        #expect(point1 != point3)
    }

    @Test("TouchPoint different isActive are not equal")
    func testTouchPointDifferentIsActive() {
        let point1 = TouchPoint(id: 0, x: 0.5, y: 0.5, isActive: true)
        let point2 = TouchPoint(id: 0, x: 0.5, y: 0.5, isActive: false)

        #expect(point1 != point2)
    }

    // MARK: - UT-014.3: Coordinate Range Validation

    /**
     * @verifies AC-062
     * @testcase UT-014.3
     */
    @Test("TouchPoint coordinates are clamped to valid range")
    func testTouchPointCoordinateRange() {
        // Minimum boundary
        let minPoint = TouchPoint(id: 0, x: 0.0, y: 0.0, isActive: true)
        #expect(minPoint.x == 0.0)
        #expect(minPoint.y == 0.0)

        // Maximum boundary
        let maxPoint = TouchPoint(id: 0, x: 1.0, y: 1.0, isActive: true)
        #expect(maxPoint.x == 1.0)
        #expect(maxPoint.y == 1.0)

        // Middle value
        let midPoint = TouchPoint(id: 0, x: 0.5, y: 0.5, isActive: true)
        #expect(midPoint.x >= 0.0 && midPoint.x <= 1.0)
        #expect(midPoint.y >= 0.0 && midPoint.y <= 1.0)
    }

    @Test("TouchPoint clamps out-of-range values")
    func testTouchPointClamping() {
        // Values below 0 should be clamped to 0
        let belowMin = TouchPoint(id: 0, x: -0.5, y: -0.3, isActive: true)
        #expect(belowMin.x == 0.0)
        #expect(belowMin.y == 0.0)

        // Values above 1 should be clamped to 1
        let aboveMax = TouchPoint(id: 0, x: 1.5, y: 2.0, isActive: true)
        #expect(aboveMax.x == 1.0)
        #expect(aboveMax.y == 1.0)
    }

    // MARK: - UT-014.4: Multi-Touch Support

    /**
     * @verifies AC-062
     * @testcase UT-014.4
     */
    @Test("Multi-touch support with different IDs")
    func testMultiTouchSupport() {
        let primaryTouch = TouchPoint(id: 0, x: 0.3, y: 0.4, isActive: true)
        let secondaryTouch = TouchPoint(id: 1, x: 0.7, y: 0.6, isActive: true)

        // Different IDs
        #expect(primaryTouch.id == 0)
        #expect(secondaryTouch.id == 1)
        #expect(primaryTouch.id != secondaryTouch.id)

        // Both can be active simultaneously
        #expect(primaryTouch.isActive)
        #expect(secondaryTouch.isActive)
    }

    @Test("TouchpadConstants defines maximum touches as 2")
    func testMaxTouches() {
        #expect(TouchpadConstants.maxTouches == 2)
    }

    // MARK: - Additional Tests

    @Test("TouchPoint raw coordinate conversion")
    func testRawCoordinateConversion() {
        let point = TouchPoint(id: 0, x: 0.5, y: 0.5, isActive: true)

        // rawX should be 960 (0.5 * 1920)
        #expect(point.rawX == 960)
        // rawY should be ~540 (0.5 * 1079)
        #expect(point.rawY == 539) // Float math: 0.5 * 1079 = 539.5 -> 539
    }

    @Test("TouchPoint inactive factory method")
    func testInactiveTouchPoint() {
        let inactive = TouchPoint.inactive(id: 0)

        #expect(inactive.id == 0)
        #expect(inactive.x == 0)
        #expect(inactive.y == 0)
        #expect(inactive.isActive == false)
    }

    @Test("TouchPoint Identifiable conformance")
    func testIdentifiableConformance() {
        let point1 = TouchPoint(id: 0, x: 0.5, y: 0.5, isActive: true)
        let point2 = TouchPoint(id: 1, x: 0.5, y: 0.5, isActive: true)

        // id property should be accessible for Identifiable
        #expect(point1.id == 0)
        #expect(point2.id == 1)
    }

    @Test("TouchpadConstants has correct maximum values")
    func testTouchpadConstants() {
        #expect(TouchpadConstants.maxX == 1920)
        #expect(TouchpadConstants.maxY == 1079)
        #expect(TouchpadConstants.maxTouches == 2)
    }

    // MARK: - ChiakiControllerInput Touchpad Tests

    @Test("ChiakiControllerInput touchpad array is initially empty")
    func testControllerInputTouchpadInitiallyEmpty() {
        let input = ChiakiControllerInput()

        #expect(input.touchpad.isEmpty)
        #expect(input.hasTouchpadInput == false)
    }

    @Test("ChiakiControllerInput hasTouchpadInput returns true when active touch exists")
    func testControllerInputHasTouchpadInput() {
        var input = ChiakiControllerInput()

        // No active touches
        #expect(input.hasTouchpadInput == false)

        // Add inactive touch
        input.touchpad.append(TouchPoint(id: 0, x: 0.5, y: 0.5, isActive: false))
        #expect(input.hasTouchpadInput == false)

        // Add active touch
        input.touchpad.append(TouchPoint(id: 1, x: 0.5, y: 0.5, isActive: true))
        #expect(input.hasTouchpadInput == true)
    }
}
