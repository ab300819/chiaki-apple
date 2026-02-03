// SPDX-License-Identifier: AGPL-3.0-only
//
// HostQuickActionTests.swift
// ChiakiTests
//
// Tests for host quick action bar
// @verifies AC-065 - 主机快速操作栏

import Testing
import SwiftUI
@testable import Chiaki

@Suite("HostQuickAction Tests")
struct HostQuickActionTests {

    // MARK: - UT-017.1: Enum Cases

    /**
     * @verifies AC-065
     * @testcase UT-017.1
     */
    @Test("Quick action enum contains all required cases")
    func testHostQuickActionEnumCases() {
        let allCases: [HostQuickAction] = [.wake, .connect, .pin, .delete]
        #expect(allCases.count == 4)

        // Verify CaseIterable conformance
        #expect(HostQuickAction.allCases.count == 4)
        #expect(HostQuickAction.allCases.contains(.wake))
        #expect(HostQuickAction.allCases.contains(.connect))
        #expect(HostQuickAction.allCases.contains(.pin))
        #expect(HostQuickAction.allCases.contains(.delete))
    }

    // MARK: - UT-017.2: Hashable Conformance

    /**
     * @verifies AC-065
     * @testcase UT-017.2
     */
    @Test("Quick action is Hashable for FocusState")
    func testHostQuickActionHashable() {
        let action1 = HostQuickAction.wake
        let action2 = HostQuickAction.wake
        let action3 = HostQuickAction.connect

        #expect(action1.hashValue == action2.hashValue)
        #expect(action1.hashValue != action3.hashValue)

        // Can be used as dictionary key
        var dict: [HostQuickAction: String] = [:]
        dict[.wake] = "Wake"
        dict[.connect] = "Connect"
        #expect(dict[.wake] == "Wake")
        #expect(dict[.connect] == "Connect")
    }

    @Test("Quick action Equatable conformance")
    func testHostQuickActionEquatable() {
        #expect(HostQuickAction.wake == HostQuickAction.wake)
        #expect(HostQuickAction.wake != HostQuickAction.connect)
        #expect(HostQuickAction.pin != HostQuickAction.delete)
    }

    // MARK: - UT-017.3: Default Focus for Standby Host

    /**
     * @verifies AC-065
     * @testcase UT-017.3
     */
    @Test("Default focus for standby host is wake")
    func testDefaultFocusForStandbyHost() {
        let standbyHost = ConsoleHost.mockStandby
        let defaultFocus = HostQuickAction.defaultFocus(for: standbyHost)
        #expect(defaultFocus == .wake)
    }

    // MARK: - UT-017.4: Default Focus for Ready Host

    /**
     * @verifies AC-065
     * @testcase UT-017.4
     */
    @Test("Default focus for ready/online host is connect")
    func testDefaultFocusForReadyHost() {
        let onlineHost = ConsoleHost.mockOnline
        let defaultFocus = HostQuickAction.defaultFocus(for: onlineHost)
        #expect(defaultFocus == .connect)
    }

    @Test("Default focus for offline host is connect")
    func testDefaultFocusForOfflineHost() {
        let offlineHost = ConsoleHost.mockOffline
        let defaultFocus = HostQuickAction.defaultFocus(for: offlineHost)
        #expect(defaultFocus == .connect)
    }

    // MARK: - UT-017.5: Action Visibility for Standby

    /**
     * @verifies AC-065
     * @testcase UT-017.5
     */
    @Test("Standby host shows wake, hides connect")
    func testActionVisibilityForStandby() {
        let standbyHost = ConsoleHost.mockStandby
        let visibleActions = HostQuickAction.visibleActions(for: standbyHost)

        #expect(visibleActions.contains(.wake))
        #expect(!visibleActions.contains(.connect))
        #expect(visibleActions.contains(.pin))
        #expect(visibleActions.contains(.delete))
    }

    // MARK: - UT-017.6: Action Visibility for Ready

    /**
     * @verifies AC-065
     * @testcase UT-017.6
     */
    @Test("Ready/online host shows connect, hides wake")
    func testActionVisibilityForReady() {
        let onlineHost = ConsoleHost.mockOnline
        let visibleActions = HostQuickAction.visibleActions(for: onlineHost)

        #expect(visibleActions.contains(.connect))
        #expect(!visibleActions.contains(.wake))
        #expect(visibleActions.contains(.pin))
        #expect(visibleActions.contains(.delete))
    }

    @Test("Offline host shows connect, hides wake")
    func testActionVisibilityForOffline() {
        let offlineHost = ConsoleHost.mockOffline
        let visibleActions = HostQuickAction.visibleActions(for: offlineHost)

        #expect(visibleActions.contains(.connect))
        #expect(!visibleActions.contains(.wake))
        #expect(visibleActions.contains(.pin))
        #expect(visibleActions.contains(.delete))
    }

    // MARK: - Additional Tests

    @Test("Action icon names are valid SF Symbols")
    func testActionIconNames() {
        #expect(HostQuickAction.wake.iconName == "power")
        #expect(HostQuickAction.connect.iconName == "play.fill")
        #expect(HostQuickAction.pin.iconName == "lock")
        #expect(HostQuickAction.delete.iconName == "trash")
    }

    @Test("Action colors are appropriate")
    func testActionColors() {
        // Wake uses orange (power state)
        #expect(HostQuickAction.wake.color == .orange)
        // Connect uses green (positive action)
        #expect(HostQuickAction.connect.color == .green)
        // Pin uses blue (neutral action)
        #expect(HostQuickAction.pin.color == .blue)
        // Delete uses red (destructive action)
        #expect(HostQuickAction.delete.color == .red)
    }

    @Test("Action localizedTitle returns non-empty strings")
    func testActionLocalizedTitles() {
        for action in HostQuickAction.allCases {
            #expect(!action.localizedTitle.isEmpty)
        }
    }
}
