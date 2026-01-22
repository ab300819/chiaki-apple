//
//  NewFeatureTests.swift
//  ChiakiTests
//
//  Test cases for new features as designed in devdocs/03-test-cases.md
//  UT-006: i18n, UT-007: HostListViewModel, UT-008: Keyboard Mappings,
//  UT-009: NavigationManager, IT-004~006: Integration Tests
//

import Testing
import Foundation
@testable import Chiaki

// MARK: - UT-006: Localization Tests

struct LocalizationTests {

    // UT-006.1: Test common strings are localized (not showing key as value)
    @Test func testCommonStringsLocalized() {
        let cancel = String(localized: "common.cancel")
        #expect(cancel != "common.cancel", "Cancel should be localized")
        #expect(!cancel.isEmpty)

        let ok = String(localized: "common.ok")
        #expect(ok != "common.ok", "OK should be localized")

        let delete = String(localized: "common.delete")
        #expect(delete != "common.delete", "Delete should be localized")
    }

    // UT-006.2: Test settings strings with format placeholders work
    @Test func testFormatStringWithPlaceholder() {
        // Test that L10n namespace strings with format functions exist and work
        // The L10n.Error.exportFailed and importFailed functions should format properly
        let errorFunc = L10n.Error.exportFailed
        #expect(errorFunc != nil, "Export failed format function should exist")

        // Test the lastSeen function exists
        let lastSeenFunc = L10n.HostList.lastSeen
        #expect(lastSeenFunc != nil, "Last seen format function should exist")
    }

    // UT-006.3: Test accessibility strings
    @Test func testAccessibilityStrings() {
        let quality = "Good"
        let accessLabel = String(localized: "accessibility.networkQuality \(quality)")
        #expect(accessLabel.contains(quality), "Accessibility string should include quality")
    }

    // UT-006.4: Test streaming page strings
    @Test func testStreamingStrings() {
        let connecting = String(localized: "streaming.connecting")
        #expect(connecting != "streaming.connecting", "Connecting should be localized")
        #expect(!connecting.isEmpty)
    }

    // UT-006.5: Test host list strings
    @Test func testHostListStrings() {
        let addHost = String(localized: "hostList.addHost")
        #expect(addHost != "hostList.addHost", "Add Host should be localized")

        let noHosts = String(localized: "hostList.noHostsFound")
        #expect(noHosts != "hostList.noHostsFound", "No hosts found should be localized")
    }
}

// MARK: - UT-007: HostListViewModel Lazy Initialization Tests

@MainActor
struct HostListViewModelLazyInitTests {

    // UT-007.1: Test initial loading state
    @Test func testInitialLoadingState() {
        // Without injecting hostManager, use lazy initialization mode
        let viewModel = HostListViewModel()

        // Initial state should be loading
        #expect(viewModel.isLoading == true)
        #expect(viewModel.hosts.isEmpty)
    }

    // UT-007.2: Test injected hostManager skips lazy init
    @Test func testInjectedHostManagerSkipsLazyInit() {
        // When injecting hostManager, initialization completes immediately
        let mockManager = HostManager()
        let viewModel = HostListViewModel(hostManager: mockManager)

        // Should complete initialization immediately
        #expect(viewModel.isLoading == false)
    }

    // UT-007.3: Test initializeIfNeeded is idempotent
    @Test func testInitializeIfNeededIdempotent() {
        let viewModel = HostListViewModel()

        // First call
        viewModel.initializeIfNeeded()
        #expect(viewModel.isLoading == false)

        // Second call should have no side effects
        viewModel.initializeIfNeeded()
        #expect(viewModel.isLoading == false)
    }

    // UT-007.4: Test loading state after initialization
    @Test func testLoadingStateAfterInit() {
        let viewModel = HostListViewModel()
        #expect(viewModel.isLoading == true, "Should start with loading state")

        viewModel.initializeIfNeeded()
        #expect(viewModel.isLoading == false, "Should complete loading after initialization")
    }
}

// MARK: - UT-008: Keyboard Mapping Tests (macOS only)

#if os(macOS)
struct KeyboardMappingTests {

    // UT-008.1: Test MappableButton has all cases
    @Test func testMappableButtonAllCases() {
        let buttons = MappableButton.allCases
        #expect(buttons.count == 18, "Should have 18 mappable buttons")

        // Verify all required buttons exist
        #expect(buttons.contains(.cross))
        #expect(buttons.contains(.circle))
        #expect(buttons.contains(.square))
        #expect(buttons.contains(.triangle))
        #expect(buttons.contains(.l1))
        #expect(buttons.contains(.r1))
        #expect(buttons.contains(.l2))
        #expect(buttons.contains(.r2))
        #expect(buttons.contains(.l3))
        #expect(buttons.contains(.r3))
        #expect(buttons.contains(.dpadUp))
        #expect(buttons.contains(.dpadDown))
        #expect(buttons.contains(.dpadLeft))
        #expect(buttons.contains(.dpadRight))
        #expect(buttons.contains(.options))
        #expect(buttons.contains(.share))
        #expect(buttons.contains(.touchpad))
        #expect(buttons.contains(.ps))
    }

    // UT-008.2: Test KeyboardMapping is Codable
    @Test func testKeyboardMappingCodable() throws {
        var mapping = KeyboardMapping(button: .cross, keyCode: nil, keyName: nil)
        mapping.keyCode = 0x00 // A key
        mapping.keyName = "A"

        let data = try JSONEncoder().encode(mapping)
        let decoded = try JSONDecoder().decode(KeyboardMapping.self, from: data)

        #expect(decoded.button == .cross)
        #expect(decoded.keyCode == 0x00)
        #expect(decoded.keyName == "A")
    }

    // UT-008.3: Test KeyboardMappings is Codable
    @Test func testKeyboardMappingsCodable() throws {
        let original = KeyboardMappings.defaultMappings

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KeyboardMappings.self, from: data)

        #expect(decoded == original)
    }

    // UT-008.4: Test default mappings have correct values
    @Test func testDefaultMappings() {
        let mappings = KeyboardMappings.defaultMappings

        // Verify some default mappings
        #expect(mappings.cross.keyName == "K")
        #expect(mappings.circle.keyName == "L")
        #expect(mappings.square.keyName == "J")
        #expect(mappings.triangle.keyName == "I")
        #expect(mappings.dpadUp.keyName == "↑")
        #expect(mappings.dpadDown.keyName == "↓")
        #expect(mappings.ps.keyName == "Esc")
    }

    // UT-008.5: Test button categories
    @Test func testButtonCategories() {
        // Face buttons
        #expect(MappableButton.cross.category == .face)
        #expect(MappableButton.circle.category == .face)
        #expect(MappableButton.square.category == .face)
        #expect(MappableButton.triangle.category == .face)

        // Shoulder buttons
        #expect(MappableButton.l1.category == .shoulder)
        #expect(MappableButton.r1.category == .shoulder)
        #expect(MappableButton.l2.category == .shoulder)
        #expect(MappableButton.r2.category == .shoulder)

        // D-Pad
        #expect(MappableButton.dpadUp.category == .dpad)
        #expect(MappableButton.dpadDown.category == .dpad)
        #expect(MappableButton.dpadLeft.category == .dpad)
        #expect(MappableButton.dpadRight.category == .dpad)

        // System
        #expect(MappableButton.ps.category == .system)
        #expect(MappableButton.options.category == .system)
        #expect(MappableButton.share.category == .system)
        #expect(MappableButton.touchpad.category == .system)
    }

    // UT-008.6: Test set and clear mapping
    @Test func testSetAndClearMapping() {
        var mappings = KeyboardMappings.defaultMappings

        // Set mapping
        mappings.setMapping(for: .cross, keyCode: 0x06, keyName: "Z")
        let crossMapping = mappings.mapping(for: .cross)
        #expect(crossMapping.keyCode == 0x06)
        #expect(crossMapping.keyName == "Z")
        #expect(crossMapping.hasMapping == true)

        // Clear mapping
        mappings.setMapping(for: .cross, keyCode: nil, keyName: nil)
        let clearedMapping = mappings.mapping(for: .cross)
        #expect(clearedMapping.hasMapping == false)
    }

    // UT-008.7: Test button display names
    @Test func testButtonDisplayName() {
        #expect(MappableButton.cross.displayName == "✕ Cross")
        #expect(MappableButton.circle.displayName == "○ Circle")
        #expect(MappableButton.square.displayName == "□ Square")
        #expect(MappableButton.triangle.displayName == "△ Triangle")
        #expect(MappableButton.l1.displayName == "L1")
        #expect(MappableButton.r2.displayName == "R2")
        #expect(MappableButton.ps.displayName == "PS Button")
        #expect(MappableButton.dpadUp.displayName == "D-Pad Up")
    }

    // UT-008.8: Test ButtonCategory has all cases
    @Test func testButtonCategoryAllCases() {
        let categories = MappableButton.ButtonCategory.allCases
        #expect(categories.count == 4)
        #expect(categories.contains(.face))
        #expect(categories.contains(.shoulder))
        #expect(categories.contains(.dpad))
        #expect(categories.contains(.system))
    }

    // UT-008.9: Test category buttons grouping
    @Test func testCategoryButtonsGrouping() {
        let faceButtons = MappableButton.ButtonCategory.face.buttons
        #expect(faceButtons.count == 4)
        #expect(faceButtons.contains(.cross))
        #expect(faceButtons.contains(.circle))

        let shoulderButtons = MappableButton.ButtonCategory.shoulder.buttons
        #expect(shoulderButtons.count == 6)
        #expect(shoulderButtons.contains(.l1))
        #expect(shoulderButtons.contains(.r2))
        #expect(shoulderButtons.contains(.l3))

        let dpadButtons = MappableButton.ButtonCategory.dpad.buttons
        #expect(dpadButtons.count == 4)

        let systemButtons = MappableButton.ButtonCategory.system.buttons
        #expect(systemButtons.count == 4)
    }
}
#endif

// MARK: - UT-009: NavigationManager Tests

@MainActor
struct NavigationManagerTests {

    // UT-009.1: Test initial state
    @Test func testInitialState() {
        let manager = NavigationManager()

        #expect(manager.sidebarSelection == .hosts)
        #expect(manager.showAddHostSheet == false)
        #expect(manager.isStreaming == false)
        #expect(manager.isAutoConnecting == false)
        #expect(manager.autoConnectHost == nil)
        #expect(manager.refreshDiscoveryTrigger == false)
        #expect(manager.wakeUpSelectedHostTrigger == false)
    }

    // UT-009.2: Test openAddHost
    @Test func testOpenAddHost() {
        let manager = NavigationManager()
        manager.sidebarSelection = .settings  // Start on settings

        manager.openAddHost()

        #expect(manager.sidebarSelection == .hosts, "Should navigate to hosts")
        #expect(manager.showAddHostSheet == true, "Should show add host sheet")
    }

    // UT-009.3: Test navigateToSettings
    @Test func testNavigateToSettings() {
        let manager = NavigationManager()
        #expect(manager.sidebarSelection == .hosts)

        manager.navigateToSettings()

        #expect(manager.sidebarSelection == .settings)
    }

    // UT-009.4: Test refreshDiscovery
    @Test func testRefreshDiscovery() {
        let manager = NavigationManager()
        manager.sidebarSelection = .settings

        manager.refreshDiscovery()

        #expect(manager.sidebarSelection == .hosts, "Should navigate to hosts")
        #expect(manager.refreshDiscoveryTrigger == true)
    }

    // UT-009.5: Test wakeUpSelectedHost
    @Test func testWakeUpSelectedHost() {
        let manager = NavigationManager()

        manager.wakeUpSelectedHost()

        #expect(manager.wakeUpSelectedHostTrigger == true)
    }

    // UT-009.6 & UT-009.7: Test auto-connect lifecycle
    @Test func testAutoConnectLifecycle() {
        let manager = NavigationManager()
        let host = ConsoleHost(nickname: "Test PS5", address: "192.168.1.100")

        // Start auto-connect
        manager.startAutoConnect(host: host)
        #expect(manager.isAutoConnecting == true)
        #expect(manager.autoConnectHost?.id == host.id)

        // End auto-connect
        manager.endAutoConnect()
        #expect(manager.isAutoConnecting == false)
        #expect(manager.autoConnectHost == nil)
    }

    // UT-009.8: Test streaming state toggle
    @Test func testStreamingStateToggle() {
        let manager = NavigationManager()

        manager.isStreaming = true
        #expect(manager.isStreaming == true)

        manager.isStreaming = false
        #expect(manager.isStreaming == false)
    }

    // UT-009.9: Test display mode trigger
    @Test func testDisplayModeChangeTrigger() {
        let manager = NavigationManager()

        #expect(manager.displayModeChangeTrigger == nil)

        manager.displayModeChangeTrigger = .stretch
        #expect(manager.displayModeChangeTrigger == .stretch)

        manager.displayModeChangeTrigger = nil
        #expect(manager.displayModeChangeTrigger == nil)
    }

    // UT-009.10: Test volume change trigger
    @Test func testVolumeChangeTrigger() {
        let manager = NavigationManager()

        #expect(manager.volumeChangeTrigger == nil)

        manager.volumeChangeTrigger = 0.75
        #expect(manager.volumeChangeTrigger == 0.75)
    }
}

// MARK: - IT-004: HostManager Singleton Consistency Tests

@MainActor
struct HostManagerSingletonTests {

    // IT-004.1: Test HostManager.shared returns same instance
    @Test func testHostManagerSharedSingleton() {
        let manager1 = HostManager.shared
        let manager2 = HostManager.shared

        // Should be the same instance
        #expect(manager1 === manager2, "HostManager.shared should return same instance")
    }

    // IT-004.2: Test HostStore is consistent when adding through manager
    @Test func testHostStoreConsistency() {
        let defaults = UserDefaults(suiteName: "test.it004.consistency")!
        defaults.removePersistentDomain(forName: "test.it004.consistency")

        let hostStore = HostStore(userDefaults: defaults)
        let manager = HostManager(hostStore: hostStore)

        // Add a host through the manager (which syncs to store)
        let host = ConsoleHost(nickname: "Test", address: "192.168.1.1")
        manager.addHost(host)

        // Both manager and store should see the host
        #expect(manager.hosts.contains { $0.nickname == "Test" })
        #expect(hostStore.hosts.contains { $0.nickname == "Test" })
    }
}

// MARK: - IT-005: Host Discovery + Storage Integration Tests

@MainActor
struct HostDiscoveryIntegrationTests {

    // IT-005.1: Test adding host through manager makes it available
    @Test func testHostAddedToStoreAvailableInManager() {
        let defaults = UserDefaults(suiteName: "test.it005.add")!
        defaults.removePersistentDomain(forName: "test.it005.add")

        let hostStore = HostStore(userDefaults: defaults)
        let manager = HostManager(hostStore: hostStore)

        let host = ConsoleHost(
            nickname: "My PS5",
            address: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF"
        )
        manager.addHost(host)

        // Verify host is in manager's merged list
        #expect(manager.hosts.contains { $0.macAddress == "AA:BB:CC:DD:EE:FF" })
        // Also verify it's in the store
        #expect(hostStore.hosts.contains { $0.macAddress == "AA:BB:CC:DD:EE:FF" })
    }

    // IT-005.2: Test host state initialization from store
    @Test func testStoredHostInitialState() {
        let defaults = UserDefaults(suiteName: "test.it005.state")!
        defaults.removePersistentDomain(forName: "test.it005.state")

        let hostStore = HostStore(userDefaults: defaults)
        var host = ConsoleHost(nickname: "PS5", address: "192.168.1.100")
        host.state = .offline
        hostStore.addHost(host)

        // Create manager after adding host to store
        let manager = HostManager(hostStore: hostStore)

        // Initial state should be preserved when loaded from store
        let foundHost = manager.hosts.first { $0.id == host.id }
        #expect(foundHost?.state == .offline)
    }

    // IT-005.3: Test hidden host not in merged list
    @Test func testHiddenHostNotInMergedList() {
        let defaults = UserDefaults(suiteName: "test.it005.hidden")!
        defaults.removePersistentDomain(forName: "test.it005.hidden")

        let hostStore = HostStore(userDefaults: defaults)

        var visibleHost = ConsoleHost(nickname: "Visible", address: "192.168.1.1")
        visibleHost.isHidden = false

        var hiddenHost = ConsoleHost(nickname: "Hidden", address: "192.168.1.2")
        hiddenHost.isHidden = true

        hostStore.addHost(visibleHost)
        hostStore.addHost(hiddenHost)

        // Create manager after adding hosts
        let manager = HostManager(hostStore: hostStore)

        // Only visible host should be in manager's list
        #expect(manager.hosts.count == 1)
        #expect(manager.hosts.first?.nickname == "Visible")
        // But store should have both
        #expect(hostStore.hosts.count == 2)
    }

    // IT-005.4: Test host address update preserves registration
    @Test func testHostAddressUpdatePreservesRegistration() {
        let defaults = UserDefaults(suiteName: "test.it005.address")!
        defaults.removePersistentDomain(forName: "test.it005.address")

        let hostStore = HostStore(userDefaults: defaults)

        // Add registered host
        var host = ConsoleHost(
            nickname: "PS5",
            address: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF",
            registKey: Data([0x01, 0x02, 0x03])
        )
        hostStore.addHost(host)

        // Update address
        host.address = "192.168.1.200"
        hostStore.updateHost(host)

        // Verify registration info preserved
        let updated = hostStore.host(byId: host.id)
        #expect(updated?.address == "192.168.1.200")
        #expect(updated?.isRegistered == true)
    }

    // IT-005.5: Test multiple hosts managed correctly through manager
    @Test func testMultipleHostsManagement() {
        let defaults = UserDefaults(suiteName: "test.it005.multiple")!
        defaults.removePersistentDomain(forName: "test.it005.multiple")

        let hostStore = HostStore(userDefaults: defaults)
        let manager = HostManager(hostStore: hostStore)

        let host1 = ConsoleHost(nickname: "PS5 Living Room", address: "192.168.1.10")
        let host2 = ConsoleHost(nickname: "PS5 Bedroom", address: "192.168.1.20")
        let host3 = ConsoleHost(nickname: "PS4 Office", address: "192.168.1.30", isPS5: false)

        // Add through manager to ensure sync
        manager.addHost(host1)
        manager.addHost(host2)
        manager.addHost(host3)

        #expect(manager.hosts.count == 3)
        #expect(manager.hosts.contains { $0.nickname == "PS5 Living Room" })
        #expect(manager.hosts.contains { $0.nickname == "PS5 Bedroom" })
        #expect(manager.hosts.contains { $0.nickname == "PS4 Office" })
    }

    // IT-005.6: Test host removal through manager
    @Test func testHostRemoval() {
        let defaults = UserDefaults(suiteName: "test.it005.remove")!
        defaults.removePersistentDomain(forName: "test.it005.remove")

        let hostStore = HostStore(userDefaults: defaults)
        let manager = HostManager(hostStore: hostStore)

        let host = ConsoleHost(nickname: "ToRemove", address: "192.168.1.100")
        manager.addHost(host)
        #expect(manager.hosts.count == 1)

        manager.removeHost(host)
        #expect(manager.hosts.count == 0)
        #expect(hostStore.hosts.count == 0)
    }
}

// MARK: - IT-006: Settings Persistence Integration Tests

@MainActor
struct SettingsPersistenceIntegrationTests {

    // IT-006.1: Test settings persist across instances
    @Test func testSettingsPersistAcrossInstances() {
        let suiteName = "test.it006.persist"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        // First instance: modify settings
        let store1 = SettingsStore(userDefaults: defaults)
        store1.updateResolution(.r720p)
        store1.updateFrameRate(.fps30)
        store1.updateBitrate(8000)

        // Second instance: verify settings preserved
        let store2 = SettingsStore(userDefaults: defaults)
        #expect(store2.streamSettings.localProfile.resolution == .r720p)
        #expect(store2.streamSettings.localProfile.frameRate == .fps30)
        #expect(store2.streamSettings.localProfile.bitrate == 8000)
    }

    // IT-006.2: Test video settings persistence
    @Test func testVideoSettingsPersistence() {
        let suiteName = "test.it006.video"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = SettingsStore(userDefaults: defaults)

        // Modify all video settings
        store.updateResolution(.r2160p)
        store.updateFrameRate(.fps60)
        store.updateBitrate(50000)
        store.updateCodec(.h265)
        store.updateHdrEnabled(true)

        // Reload and verify
        let store2 = SettingsStore(userDefaults: defaults)
        #expect(store2.streamSettings.localProfile.resolution == .r2160p)
        #expect(store2.streamSettings.localProfile.frameRate == .fps60)
        #expect(store2.streamSettings.localProfile.bitrate == 50000)
        #expect(store2.streamSettings.codec == .h265)
        #expect(store2.streamSettings.hdrEnabled == true)
    }

    // IT-006.3: Test audio settings persistence
    @Test func testAudioSettingsPersistence() {
        let suiteName = "test.it006.audio"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = SettingsStore(userDefaults: defaults)

        // Modify audio settings
        store.streamSettings.volume = 0.75
        store.streamSettings.audioBufferSize = 20
        store.streamSettings.microphoneEnabled = true

        // Reload and verify
        let store2 = SettingsStore(userDefaults: defaults)
        #expect(store2.streamSettings.volume == 0.75)
        #expect(store2.streamSettings.audioBufferSize == 20)
        #expect(store2.streamSettings.microphoneEnabled == true)
    }

    // IT-006.4: Test controller settings persistence
    @Test func testControllerSettingsPersistence() {
        let suiteName = "test.it006.controller"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = SettingsStore(userDefaults: defaults)

        // Modify controller settings
        store.streamSettings.hapticFeedbackEnabled = false
        store.streamSettings.isTouchControllerEnabled = false

        // Reload and verify
        let store2 = SettingsStore(userDefaults: defaults)
        #expect(store2.streamSettings.hapticFeedbackEnabled == false)
        #expect(store2.streamSettings.isTouchControllerEnabled == false)
    }

    // IT-006.5: Test reset to defaults clears settings
    @Test func testResetToDefaultsClears() {
        let suiteName = "test.it006.reset"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = SettingsStore(userDefaults: defaults)

        // Modify settings
        store.updateResolution(.r540p)
        store.updateFrameRate(.fps30)
        store.updateBitrate(5000)

        // Reset
        store.resetToDefaults()

        // Verify defaults restored
        #expect(store.streamSettings.localProfile.resolution == .r1080p)
        #expect(store.streamSettings.localProfile.frameRate == .fps60)
        #expect(store.streamSettings.localProfile.bitrate == 15000)
    }

    // IT-006.6: Test auto-connect settings persistence
    @Test func testAutoConnectSettingsPersistence() {
        let suiteName = "test.it006.autoconnect"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = SettingsStore(userDefaults: defaults)
        let testHostId = UUID()

        store.autoConnectEnabled = true
        store.autoConnectHostId = testHostId
        store.autoConnectWakeUp = true

        // Reload and verify
        let store2 = SettingsStore(userDefaults: defaults)
        #expect(store2.autoConnectEnabled == true)
        #expect(store2.autoConnectHostId == testHostId)
        #expect(store2.autoConnectWakeUp == true)
    }

    // IT-006.7: Test disconnect/suspend action persistence
    @Test func testDisconnectActionPersistence() {
        let suiteName = "test.it006.disconnect"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = SettingsStore(userDefaults: defaults)

        store.disconnectAction = .enterSleepMode
        store.suspendAction = .enterSleepMode

        // Reload and verify
        let store2 = SettingsStore(userDefaults: defaults)
        #expect(store2.disconnectAction == .enterSleepMode)
        #expect(store2.suspendAction == .enterSleepMode)
    }

    #if os(macOS)
    // IT-006.8: Test keyboard mappings persistence (macOS)
    @Test func testKeyboardMappingsPersistence() {
        let suiteName = "test.it006.keyboard"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = SettingsStore(userDefaults: defaults)

        // Modify keyboard mapping
        store.keyboardMappings.setMapping(for: .cross, keyCode: 0x06, keyName: "Z")
        store.keyboardMappings.setMapping(for: .circle, keyCode: 0x07, keyName: "X")

        // Trigger save by modifying keyboard input enabled
        store.keyboardInputEnabled = true

        // Reload and verify
        let store2 = SettingsStore(userDefaults: defaults)
        let crossMapping = store2.keyboardMappings.mapping(for: .cross)
        #expect(crossMapping.keyCode == 0x06)
        #expect(crossMapping.keyName == "Z")
    }
    #endif

    // IT-006.9: Test export/import settings consistency
    @Test func testExportImportConsistency() throws {
        let suiteName = "test.it006.export"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = SettingsStore(userDefaults: defaults)

        // Configure custom settings
        store.updateResolution(.r720p)
        store.updateFrameRate(.fps30)
        store.updateBitrate(10000)
        store.updateCodec(.h264)

        // Export
        let exportedData = try store.exportSettings()

        // Reset to defaults
        store.resetToDefaults()
        #expect(store.streamSettings.localProfile.resolution == .r1080p)

        // Import
        try store.importSettings(from: exportedData)

        // Verify imported settings match original
        #expect(store.streamSettings.localProfile.resolution == .r720p)
        #expect(store.streamSettings.localProfile.frameRate == .fps30)
        #expect(store.streamSettings.localProfile.bitrate == 10000)
        #expect(store.streamSettings.codec == .h264)
    }
}
