// SPDX-License-Identifier: AGPL-3.0-only
//
// BatteryInfoTests.swift
// ChiakiTests
//
// Tests for controller battery information display
// @verifies AC-064 - 控制器电池电量显示

import Testing
import SwiftUI
@testable import Chiaki

@Suite("BatteryInfo Tests")
struct BatteryInfoTests {

    // MARK: - UT-016.1: BatteryState Enum Cases

    /**
     * @verifies AC-064
     * @testcase UT-016.1
     */
    @Test("BatteryState enum contains all required cases")
    func testBatteryStateEnumCases() {
        let states: [ControllerOrchestrator.BatteryInfo.BatteryState] = [
            .unknown, .discharging, .charging, .full
        ]
        #expect(states.count == 4)

        // Verify raw values match GCDeviceBattery.State
        #expect(ControllerOrchestrator.BatteryInfo.BatteryState.unknown.rawValue == -1)
        #expect(ControllerOrchestrator.BatteryInfo.BatteryState.discharging.rawValue == 0)
        #expect(ControllerOrchestrator.BatteryInfo.BatteryState.charging.rawValue == 1)
        #expect(ControllerOrchestrator.BatteryInfo.BatteryState.full.rawValue == 2)
    }

    // MARK: - UT-016.2: isLow Threshold

    /**
     * @verifies AC-064
     * @testcase UT-016.2
     */
    @Test("isLow threshold is 20%")
    func testIsLowThreshold() {
        let lowBattery = ControllerOrchestrator.BatteryInfo(level: 0.15, state: .discharging)
        let normalBattery = ControllerOrchestrator.BatteryInfo(level: 0.25, state: .discharging)
        let exactThreshold = ControllerOrchestrator.BatteryInfo(level: 0.2, state: .discharging)

        #expect(lowBattery.isLow == true)
        #expect(normalBattery.isLow == false)
        #expect(exactThreshold.isLow == false) // 0.2 is not < 0.2
    }

    @Test("isLow at boundary values")
    func testIsLowBoundaryValues() {
        let justBelow = ControllerOrchestrator.BatteryInfo(level: 0.199, state: .discharging)
        let justAbove = ControllerOrchestrator.BatteryInfo(level: 0.201, state: .discharging)
        let zero = ControllerOrchestrator.BatteryInfo(level: 0.0, state: .discharging)

        #expect(justBelow.isLow == true)
        #expect(justAbove.isLow == false)
        #expect(zero.isLow == true)
    }

    // MARK: - UT-016.3: Icon Names for Levels

    /**
     * @verifies AC-064
     * @testcase UT-016.3
     */
    @Test("Icon names for different battery levels")
    func testIconNameForLevels() {
        let full = ControllerOrchestrator.BatteryInfo(level: 0.9, state: .discharging)
        let high = ControllerOrchestrator.BatteryInfo(level: 0.6, state: .discharging)
        let medium = ControllerOrchestrator.BatteryInfo(level: 0.4, state: .discharging)
        let low = ControllerOrchestrator.BatteryInfo(level: 0.1, state: .discharging)

        #expect(full.iconName == "battery.100")
        #expect(high.iconName == "battery.75")
        #expect(medium.iconName == "battery.50")
        #expect(low.iconName == "battery.25")
    }

    @Test("Icon names at boundary levels")
    func testIconNameAtBoundaries() {
        let at75 = ControllerOrchestrator.BatteryInfo(level: 0.75, state: .discharging)
        let at50 = ControllerOrchestrator.BatteryInfo(level: 0.50, state: .discharging)
        let at25 = ControllerOrchestrator.BatteryInfo(level: 0.25, state: .discharging)

        #expect(at75.iconName == "battery.100")
        #expect(at50.iconName == "battery.75")
        #expect(at25.iconName == "battery.50")
    }

    // MARK: - UT-016.4: Charging Icon

    /**
     * @verifies AC-064
     * @testcase UT-016.4
     */
    @Test("Charging state shows bolt icon")
    func testIconNameForCharging() {
        let charging = ControllerOrchestrator.BatteryInfo(level: 0.5, state: .charging)
        #expect(charging.iconName == "battery.100.bolt")
    }

    @Test("Charging icon regardless of level")
    func testChargingIconAtDifferentLevels() {
        let chargingLow = ControllerOrchestrator.BatteryInfo(level: 0.1, state: .charging)
        let chargingHigh = ControllerOrchestrator.BatteryInfo(level: 0.9, state: .charging)

        #expect(chargingLow.iconName == "battery.100.bolt")
        #expect(chargingHigh.iconName == "battery.100.bolt")
    }

    @Test("Full state shows 100% icon")
    func testFullStateIcon() {
        let full = ControllerOrchestrator.BatteryInfo(level: 1.0, state: .full)
        #expect(full.iconName == "battery.100")
    }

    // MARK: - UT-016.5: Colors for States

    /**
     * @verifies AC-064
     * @testcase UT-016.5
     */
    @Test("Colors for different battery states")
    func testColorForStates() {
        let charging = ControllerOrchestrator.BatteryInfo(level: 0.5, state: .charging)
        let full = ControllerOrchestrator.BatteryInfo(level: 1.0, state: .full)
        let low = ControllerOrchestrator.BatteryInfo(level: 0.1, state: .discharging)
        let normal = ControllerOrchestrator.BatteryInfo(level: 0.5, state: .discharging)

        #expect(charging.color == .green)
        #expect(full.color == .green)
        #expect(low.color == .red)
        #expect(normal.color == .primary)
    }

    @Test("Low battery color takes precedence over discharging")
    func testLowBatteryColorPrecedence() {
        let lowDischarging = ControllerOrchestrator.BatteryInfo(level: 0.15, state: .discharging)
        #expect(lowDischarging.color == .red)
        #expect(lowDischarging.isLow == true)
    }

    // MARK: - UT-016.6: Equatable

    /**
     * @verifies AC-064
     * @testcase UT-016.6
     */
    @Test("BatteryInfo Equatable conformance")
    func testBatteryInfoEquatable() {
        let info1 = ControllerOrchestrator.BatteryInfo(level: 0.5, state: .charging)
        let info2 = ControllerOrchestrator.BatteryInfo(level: 0.5, state: .charging)
        let info3 = ControllerOrchestrator.BatteryInfo(level: 0.6, state: .charging)
        let info4 = ControllerOrchestrator.BatteryInfo(level: 0.5, state: .discharging)

        #expect(info1 == info2)
        #expect(info1 != info3)
        #expect(info1 != info4)
    }

    // MARK: - Additional Tests

    @Test("Percentage string format")
    func testPercentageString() {
        let battery75 = ControllerOrchestrator.BatteryInfo(level: 0.75, state: .discharging)
        let battery100 = ControllerOrchestrator.BatteryInfo(level: 1.0, state: .full)
        let battery0 = ControllerOrchestrator.BatteryInfo(level: 0.0, state: .discharging)

        #expect(battery75.percentageString == "75%")
        #expect(battery100.percentageString == "100%")
        #expect(battery0.percentageString == "0%")
    }

    @Test("Unknown state handling")
    func testUnknownState() {
        let unknown = ControllerOrchestrator.BatteryInfo(level: 0.5, state: .unknown)

        // Unknown state should use level-based icon
        #expect(unknown.iconName == "battery.75")
        // Unknown state should use primary color (not charging green)
        #expect(unknown.color == .primary)
    }
}
