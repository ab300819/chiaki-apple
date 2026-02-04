// SPDX-License-Identifier: AGPL-3.0-only
//
// ConsolesSettingsViewModelTests.swift
// ChiakiTests
//
// @requirement F-027 - UI 层 MVVM 合规重构
// @verifies AC-094 - ConsolesSettingsViewModel

import Foundation
import Testing
@testable import Chiaki

@Suite("ConsolesSettingsViewModel Tests")
@MainActor
struct ConsolesSettingsViewModelTests {

    // MARK: - Helper

    /// Create an isolated HostStore for testing
    private func makeIsolatedHostStore() -> HostStore {
        let suiteName = "ConsolesSettingsViewModelTests-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return HostStore(userDefaults: userDefaults)
    }

    // MARK: - Mock

    private final class MockPinManager: PinManaging, @unchecked Sendable {
        var pins: [UUID: String] = [:]
        var setPinCalled = false
        var clearPinCalled = false
        var lastClearedHostId: UUID?

        func setPin(_ pin: String, for host: ConsoleHost) {
            pins[host.id] = pin
            setPinCalled = true
        }

        func clearPin(for host: ConsoleHost) {
            pins.removeValue(forKey: host.id)
            clearPinCalled = true
            lastClearedHostId = host.id
        }

        func hasPin(for host: ConsoleHost) -> Bool {
            pins[host.id] != nil
        }

        func requiresPinEntry(for host: ConsoleHost) -> Bool {
            hasPin(for: host)
        }

        func getPin(for host: ConsoleHost) -> String? {
            pins[host.id]
        }
    }

    // MARK: - UT-038.1: Dependency Injection

    /**
     * @verifies AC-094 - ConsolesSettingsViewModel
     * @testcase UT-038.1
     */
    @Test("ViewModel accepts HostStore and PinManaging via constructor")
    func testDependencyInjection() {
        let hostStore = makeIsolatedHostStore()
        let pinManager = MockPinManager()
        let viewModel = ConsolesSettingsViewModel(hostStore: hostStore, pinManager: pinManager)
        #expect(viewModel != nil)
    }

    // MARK: - UT-038.2: Hosts Exposure

    /**
     * @verifies AC-094 - ConsolesSettingsViewModel
     * @testcase UT-038.2
     */
    @Test("hosts property exposes registered hosts from store")
    func testHostsExposure() {
        let hostStore = makeIsolatedHostStore()
        let pinManager = MockPinManager()

        // Add a registered host
        let host = ConsoleHost(
            nickname: "Test PS5",
            address: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF",
            isPS5: true,
            registKey: Data([0x01]),
            rpKey: Data([0x02]),
            rpKeyType: 1
        )
        hostStore.addHost(host)

        let viewModel = ConsolesSettingsViewModel(hostStore: hostStore, pinManager: pinManager)

        #expect(viewModel.registeredHosts.count == 1)
        #expect(viewModel.registeredHosts.first?.nickname == "Test PS5")
    }

    // MARK: - UT-038.3: Remove Host with PIN Cleanup

    /**
     * @verifies AC-094 - ConsolesSettingsViewModel
     * @testcase UT-038.3
     */
    @Test("removeHost clears PIN before removing host")
    func testRemoveHostClearsPIN() {
        let hostStore = makeIsolatedHostStore()
        let pinManager = MockPinManager()

        // Add a host with PIN
        let host = ConsoleHost(
            nickname: "Test PS5",
            address: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF",
            isPS5: true,
            registKey: Data([0x01]),
            rpKey: Data([0x02]),
            rpKeyType: 1
        )
        hostStore.addHost(host)
        pinManager.setPin("1234", for: host)

        let viewModel = ConsolesSettingsViewModel(hostStore: hostStore, pinManager: pinManager)

        // Remove host
        viewModel.removeHost(host)

        // Verify PIN was cleared
        #expect(pinManager.clearPinCalled == true)
        #expect(pinManager.lastClearedHostId == host.id)

        // Verify host was removed
        #expect(hostStore.hosts.isEmpty)
    }

    // MARK: - UT-038.4: Hide/Unhide Host

    /**
     * @verifies AC-094 - ConsolesSettingsViewModel
     * @testcase UT-038.4
     */
    @Test("hideHost and unhideHost delegate to store")
    func testHideUnhideHost() {
        let hostStore = makeIsolatedHostStore()
        let pinManager = MockPinManager()

        // Add a host
        var host = ConsoleHost(
            nickname: "Test PS5",
            address: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF",
            isPS5: true,
            registKey: Data([0x01]),
            rpKey: Data([0x02]),
            rpKeyType: 1
        )
        hostStore.addHost(host)

        let viewModel = ConsolesSettingsViewModel(hostStore: hostStore, pinManager: pinManager)

        // Hide host
        viewModel.hideHost(host)
        #expect(hostStore.hiddenHosts.count == 1)

        // Get updated host reference
        host = hostStore.hosts.first!

        // Unhide host
        viewModel.unhideHost(host)
        #expect(hostStore.hiddenHosts.isEmpty)
        #expect(hostStore.registeredHosts.count == 1)
    }

    // MARK: - UT-038.5: PIN Proxy Methods

    /**
     * @verifies AC-094 - ConsolesSettingsViewModel
     * @testcase UT-038.5
     */
    @Test("PIN proxy methods correctly delegate to PinManager")
    func testPINProxyMethods() {
        let hostStore = makeIsolatedHostStore()
        let pinManager = MockPinManager()

        let host = ConsoleHost(
            nickname: "Test PS5",
            address: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF",
            isPS5: true,
            registKey: Data([0x01]),
            rpKey: Data([0x02]),
            rpKeyType: 1
        )
        hostStore.addHost(host)

        let viewModel = ConsolesSettingsViewModel(hostStore: hostStore, pinManager: pinManager)

        // Test hasPin (initially false)
        #expect(viewModel.hasPin(for: host) == false)

        // Test setPin
        viewModel.setPin("5678", for: host)
        #expect(pinManager.setPinCalled == true)
        #expect(viewModel.hasPin(for: host) == true)

        // Test clearPin
        viewModel.clearPin(for: host)
        #expect(viewModel.hasPin(for: host) == false)
    }
}
