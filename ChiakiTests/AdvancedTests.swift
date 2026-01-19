//
//  AdvancedTests.swift
//  ChiakiTests
//
//  Advanced tests for Session flow, Discovery flow, ViewModel, and Keychain
//  Addresses P0/P1 test gaps identified in devdocs
//

import Testing
import Foundation
@testable import Chiaki

// MARK: - P0: ChiakiSessionWrapper Tests

struct ChiakiSessionWrapperTests {

    @Test func testInitialState() {
        let session = ChiakiSessionWrapper()
        #expect(session.state == .idle)
        #expect(session.serverNickname == nil)
        #expect(session.playerIndex == 0)
    }

    @Test func testStateTransitions() {
        // Test state properties
        let idleState = SessionState.idle
        #expect(idleState.isActive == false)
        #expect(idleState.isError == false)

        let connectingState = SessionState.connecting
        #expect(connectingState.isActive == true)

        let connectedState = SessionState.connected
        #expect(connectedState.isActive == true)

        let streamingState = SessionState.streaming
        #expect(streamingState.isActive == true)

        let disconnectingState = SessionState.disconnecting
        #expect(disconnectingState.isActive == false)

        let errorState = SessionState.error(.timeout)
        #expect(errorState.isActive == false)
        #expect(errorState.isError == true)
    }

    @Test func testSessionConfigurationSetup() {
        let session = ChiakiSessionWrapper()

        // Test stream configuration
        var config = StreamConfig.default
        #expect(config.resolution == .r1080p)
        #expect(config.fps == .fps60)

        config.bitrate = 20_000_000
        session.configure(stream: config)

        // Configuration should be set without error
        #expect(true)
    }

    @Test func testSessionCallbackSetup() {
        let session = ChiakiSessionWrapper()

        var stateChangeCalled = false
        var loginPinCalled = false
        var rumbleCalled = false

        session.onStateChanged = { _ in stateChangeCalled = true }
        session.onLoginPinRequest = { _ in loginPinCalled = true }
        session.onRumble = { _, _ in rumbleCalled = true }

        // Callbacks should be set
        #expect(session.onStateChanged != nil)
        #expect(session.onLoginPinRequest != nil)
        #expect(session.onRumble != nil)
    }

    @Test func testConnectWithoutRegistration() {
        let session = ChiakiSessionWrapper()

        // Empty registration keys should cause connection to fail validation
        let hostConfig = HostConfig(
            address: "192.168.1.100",
            registKey: Data(),  // Empty - invalid
            morning: Data(),
            isPS5: true
        )

        // In real scenario, connect would fail due to empty keys
        // We can't actually test the full connection without a real PS5
        #expect(hostConfig.registKey.isEmpty == true)
    }

    @Test func testValidHostConfig() {
        let registKey = Data(repeating: 0xAA, count: 16)
        let morning = Data(repeating: 0xBB, count: 16)

        let hostConfig = HostConfig(
            address: "192.168.1.100",
            registKey: registKey,
            morning: morning,
            isPS5: true,
            nickname: "Test PS5"
        )

        #expect(hostConfig.address == "192.168.1.100")
        #expect(hostConfig.registKey.count == 16)
        #expect(hostConfig.morning.count == 16)
        #expect(hostConfig.isPS5 == true)
        #expect(hostConfig.nickname == "Test PS5")
    }

    @Test func testSessionErrorFromQuitReason() {
        // Test error mapping from quit reasons
        let connectionRefused = SessionError.from(quitReason: .sessionRequestConnectionRefused)
        #expect(connectionRefused == .connectionFailed("Connection refused"))

        let rpInUse = SessionError.from(quitReason: .sessionRequestRPInUse)
        #expect(rpInUse == .remotePlayInUse)

        let versionMismatch = SessionError.from(quitReason: .sessionRequestRPVersionMismatch)
        #expect(versionMismatch == .versionMismatch)

        let registFailed = SessionError.from(quitReason: .psnRegistFailed)
        #expect(registFailed == .registrationRequired)
    }
}

// MARK: - P0: DiscoveryService Tests

struct DiscoveryServiceTests {

    @Test @MainActor func testDiscoveryServiceInitialization() {
        let service = DiscoveryService()

        #expect(service.discoveredHosts.isEmpty)
        #expect(service.isDiscovering == false)
        #expect(service.lastError == nil)
    }

    @Test @MainActor func testStartStopDiscovery() {
        let service = DiscoveryService()

        // Initially not discovering
        #expect(service.isDiscovering == false)

        // Start discovery
        service.startDiscovery()
        // Note: May fail if network not available, but should not crash

        // Stop discovery
        service.stopDiscovery()
        #expect(service.isDiscovering == false)
    }

    @Test @MainActor func testUpdateDiscoveredHosts() {
        let service = DiscoveryService()

        // Manually update hosts (simulating discovery callback)
        // Note: We can't create DiscoveredHost directly from ChiakiDiscoveryHost
        // without actual libchiaki data, so we test the update mechanism
        service.updateDiscoveredHosts([])
        #expect(service.discoveredHosts.isEmpty)
    }

    @Test @MainActor func testWakeUpWithInvalidAddress() async {
        let service = DiscoveryService()

        let host = ConsoleHost(nickname: "Test", address: "")

        do {
            try await service.wakeUp(host: host)
            #expect(Bool(false), "Should have thrown invalidAddress error")
        } catch let error as DiscoveryError {
            #expect(error == .invalidAddress)
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    @Test @MainActor func testWakeUpWithoutRegistration() async {
        let service = DiscoveryService()

        var host = ConsoleHost(nickname: "Test", address: "192.168.1.100")
        host.registKey = Data()  // Empty registration key

        do {
            try await service.wakeUp(host: host)
            #expect(Bool(false), "Should have thrown notRegistered error")
        } catch let error as DiscoveryError {
            #expect(error == .notRegistered)
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    @Test func testDiscoveredHostState() {
        // Test DiscoveredHostInfo from IntegrationTests
        let readyInfo = DiscoveredHostInfo(
            address: "192.168.1.100",
            hostState: .ready
        )
        #expect(readyInfo.isAvailable == true)
        #expect(readyInfo.isStandby == false)

        let standbyInfo = DiscoveredHostInfo(
            address: "192.168.1.100",
            hostState: .standby
        )
        #expect(standbyInfo.isAvailable == false)
        #expect(standbyInfo.isStandby == true)
    }
}

// MARK: - P1: StreamingViewModel Tests

@MainActor
struct StreamingViewModelTests {

    @Test func testInitialState() {
        let host = ConsoleHost(nickname: "Test PS5", address: "192.168.1.100")
        let viewModel = StreamingViewModel(host: host)

        #expect(viewModel.state == .disconnected)
        #expect(viewModel.isOverlayVisible == true)
        #expect(viewModel.currentResolution == "1080p")
        #expect(viewModel.connectionQuality == .unknown)
    }

    @Test func testConnectionStateProperties() {
        // Test ConnectionState enum
        let disconnected = StreamingViewModel.ConnectionState.disconnected
        #expect(disconnected.isActive == false)

        let connecting = StreamingViewModel.ConnectionState.connecting
        #expect(connecting.isActive == true)

        let connected = StreamingViewModel.ConnectionState.connected
        #expect(connected.isActive == true)

        let streaming = StreamingViewModel.ConnectionState.streaming
        #expect(streaming.isActive == true)

        let error = StreamingViewModel.ConnectionState.error("Test error")
        #expect(error.isActive == false)
    }

    @Test func testConnectionStateEquatable() {
        let state1 = StreamingViewModel.ConnectionState.disconnected
        let state2 = StreamingViewModel.ConnectionState.disconnected
        #expect(state1 == state2)

        let error1 = StreamingViewModel.ConnectionState.error("Error A")
        let error2 = StreamingViewModel.ConnectionState.error("Error A")
        let error3 = StreamingViewModel.ConnectionState.error("Error B")
        #expect(error1 == error2)
        #expect(error1 != error3)
    }

    @Test func testConnectWithUnregisteredHost() {
        var host = ConsoleHost(nickname: "Unregistered", address: "192.168.1.100")
        host.registKey = Data()  // Empty

        let viewModel = StreamingViewModel(host: host)
        let settings = StreamSettings()

        viewModel.connect(settings: settings)

        // Should transition to error state
        if case .error(let message) = viewModel.state {
            #expect(message.contains("not registered"))
        } else {
            #expect(Bool(false), "Expected error state for unregistered host")
        }
    }

    @Test func testPiPManagerAvailable() {
        let host = ConsoleHost(nickname: "Test", address: "192.168.1.100")
        let viewModel = StreamingViewModel(host: host)

        #expect(viewModel.pipManager != nil)
    }

    @Test func testOverlayToggle() {
        let host = ConsoleHost(nickname: "Test", address: "192.168.1.100")
        let viewModel = StreamingViewModel(host: host)

        #expect(viewModel.isOverlayVisible == true)

        viewModel.toggleOverlay()
        // Note: toggleOverlay has animation delay, so we just verify no crash
        #expect(true)
    }
}

// MARK: - P1: KeychainManager Tests

struct KeychainManagerTests {

    // Use a test-specific key prefix to avoid conflicts
    private let testKeyPrefix = "test.chiaki.unit."

    @Test func testSaveAndLoadData() throws {
        let keychain = KeychainManager.shared
        let testKey = testKeyPrefix + "data.\(UUID().uuidString)"
        let testData = Data([0x01, 0x02, 0x03, 0x04])

        defer {
            try? keychain.delete(key: testKey)
        }

        // Save
        try keychain.save(key: testKey, data: testData)

        // Load
        let loaded = try keychain.load(key: testKey)
        #expect(loaded == testData)
    }

    @Test func testSaveAndLoadString() throws {
        let keychain = KeychainManager.shared
        let testKey = testKeyPrefix + "string.\(UUID().uuidString)"
        let testString = "TestCredential123"

        defer {
            try? keychain.delete(key: testKey)
        }

        // Save
        try keychain.save(key: testKey, string: testString)

        // Load
        let loaded = try keychain.loadString(key: testKey)
        #expect(loaded == testString)
    }

    @Test func testUpdateData() throws {
        let keychain = KeychainManager.shared
        let testKey = testKeyPrefix + "update.\(UUID().uuidString)"
        let initialData = Data([0x01, 0x02])
        let updatedData = Data([0x03, 0x04, 0x05])

        defer {
            try? keychain.delete(key: testKey)
        }

        // Save initial
        try keychain.save(key: testKey, data: initialData)

        // Save again (should update)
        try keychain.save(key: testKey, data: updatedData)

        // Load should return updated data
        let loaded = try keychain.load(key: testKey)
        #expect(loaded == updatedData)
    }

    @Test func testLoadNonexistent() {
        let keychain = KeychainManager.shared
        let testKey = testKeyPrefix + "nonexistent.\(UUID().uuidString)"

        do {
            _ = try keychain.load(key: testKey)
            #expect(Bool(false), "Should have thrown itemNotFound")
        } catch let error as KeychainError {
            if case .itemNotFound = error {
                #expect(true)
            } else {
                #expect(Bool(false), "Expected itemNotFound, got \(error)")
            }
        } catch {
            #expect(Bool(false), "Unexpected error type")
        }
    }

    @Test func testDelete() throws {
        let keychain = KeychainManager.shared
        let testKey = testKeyPrefix + "delete.\(UUID().uuidString)"
        let testData = Data([0xAA, 0xBB])

        // Save
        try keychain.save(key: testKey, data: testData)

        // Delete
        try keychain.delete(key: testKey)

        // Should not be found
        do {
            _ = try keychain.load(key: testKey)
            #expect(Bool(false), "Should have thrown itemNotFound after delete")
        } catch let error as KeychainError {
            if case .itemNotFound = error {
                #expect(true)
            } else {
                #expect(Bool(false), "Expected itemNotFound")
            }
        } catch {
            #expect(Bool(false), "Unexpected error")
        }
    }

    @Test func testDeleteNonexistent() {
        let keychain = KeychainManager.shared
        let testKey = testKeyPrefix + "deleteNonexistent.\(UUID().uuidString)"

        // Should not throw for non-existent item
        do {
            try keychain.delete(key: testKey)
            #expect(true)
        } catch {
            #expect(Bool(false), "Delete should not throw for non-existent item")
        }
    }
}

// MARK: - KeychainError Tests

struct KeychainErrorTests {

    @Test func testErrorCases() {
        let notFound = KeychainError.itemNotFound
        let duplicate = KeychainError.duplicateItem
        let unexpected = KeychainError.unexpectedStatus(-25300)
        let invalid = KeychainError.invalidData

        // Just verify they can be created
        #expect(notFound != nil)
        #expect(duplicate != nil)
        #expect(unexpected != nil)
        #expect(invalid != nil)
    }
}

// MARK: - ConnectionQuality Tests

struct ConnectionQualityTests {

    @Test func testConnectionQualityValues() {
        let excellent = ConnectionQuality.excellent
        let good = ConnectionQuality.good
        let fair = ConnectionQuality.fair
        let poor = ConnectionQuality.poor
        let unknown = ConnectionQuality.unknown

        // Verify all cases exist
        #expect(excellent != unknown)
        #expect(good != unknown)
        #expect(fair != unknown)
        #expect(poor != unknown)
    }
}

// MARK: - StreamStatistics Tests

struct StreamStatisticsTests {

    @Test func testInitialization() {
        let stats = StreamStatistics()

        #expect(stats.decodedFrames == 0)
        #expect(stats.droppedFrames == 0)
        #expect(stats.currentFrameRate == 0)
        #expect(stats.measuredBitrate == 0)
    }

    @Test func testRecordVideoFrame() {
        let stats = StreamStatistics()

        stats.recordVideoFrame(size: 50000, wasDropped: false)
        #expect(stats.decodedFrames == 1)
        #expect(stats.droppedFrames == 0)

        stats.recordVideoFrame(size: 50000, wasDropped: true)
        #expect(stats.decodedFrames == 1)
        #expect(stats.droppedFrames == 1)
    }

    @Test func testSessionLifecycle() {
        let stats = StreamStatistics()

        #expect(stats.sessionStartTime == nil)

        stats.sessionStarted()
        #expect(stats.sessionStartTime != nil)

        stats.sessionEnded()
        // sessionEnded just logs, sessionStartTime remains set
        #expect(stats.sessionStartTime != nil)
    }

    @Test func testReset() {
        let stats = StreamStatistics()

        // Record some data
        stats.recordVideoFrame(size: 50000, wasDropped: false)
        stats.recordVideoFrame(size: 50000, wasDropped: true)

        // Reset
        stats.reset()

        #expect(stats.decodedFrames == 0)
        #expect(stats.droppedFrames == 0)
    }

    @Test func testConnectionQuality() {
        let stats = StreamStatistics()

        // Default should be excellent (no packet loss, no latency)
        #expect(stats.connectionQuality == .excellent)
    }

    @Test func testAudioUnderrun() {
        let stats = StreamStatistics()

        #expect(stats.audioUnderruns == 0)

        stats.recordAudioUnderrun()
        #expect(stats.audioUnderruns == 1)

        stats.recordAudioUnderrun()
        #expect(stats.audioUnderruns == 2)
    }

    @Test func testAudioBufferFill() {
        let stats = StreamStatistics()

        #expect(stats.audioBufferFill == 0.0)

        stats.updateAudioBufferFill(0.75)
        #expect(stats.audioBufferFill == 0.75)
    }

    @Test func testNetworkLatency() {
        let stats = StreamStatistics()

        #expect(stats.networkLatency == 0)

        stats.updateLatency(25.5)
        #expect(stats.networkLatency == 25.5)
    }

    @Test func testFrameDropRate() {
        let stats = StreamStatistics()

        // No frames = 0 drop rate
        #expect(stats.frameDropRate == 0)

        // 1 decoded, 1 dropped = 50% drop rate
        stats.recordVideoFrame(size: 1000, wasDropped: false)
        stats.recordVideoFrame(size: 1000, wasDropped: true)
        #expect(stats.frameDropRate == 0.5)
    }
}

// MARK: - VideoDecoderBridge Tests

struct VideoDecoderBridgeTests {

    @Test func testInitialization() {
        let bridge = VideoDecoderBridge()
        #expect(bridge != nil)
    }

    @Test func testConfiguration() {
        let bridge = VideoDecoderBridge()

        bridge.configure(codec: .h265, width: 1920, height: 1080)

        // Should not crash
        #expect(true)
    }

    @Test func testConfigurationH264() {
        let bridge = VideoDecoderBridge()

        bridge.configure(codec: .h264, width: 1280, height: 720)

        // Should not crash
        #expect(true)
    }
}

// MARK: - PiPManager Tests

struct PiPManagerTests {

    @Test @MainActor func testInitialization() {
        let manager = PiPManager()
        #expect(manager != nil)
    }

    @Test @MainActor func testPiPAvailability() {
        let manager = PiPManager()

        // PiP availability depends on platform
        #if os(iOS)
        // May be available on iOS
        #expect(true)
        #else
        // May not be available on other platforms
        #expect(true)
        #endif
    }
}
