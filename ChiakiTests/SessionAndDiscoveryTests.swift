//
//  SessionAndDiscoveryTests.swift
//  ChiakiTests
//
//  Unit tests for ChiakiSession and Discovery (UT-001, UT-002)
//

import Testing
import Foundation
@testable import Chiaki

// MARK: - UT-001: Session State Tests

struct SessionStateTests {

    @Test func testInitialState() {
        let state = SessionState.idle
        #expect(state == .idle)
        #expect(state.isActive == false)
        #expect(state.isError == false)
    }

    @Test func testConnectingState() {
        let state = SessionState.connecting
        #expect(state.isActive == true)
        #expect(state.isError == false)
    }

    @Test func testConnectedState() {
        let state = SessionState.connected
        #expect(state.isActive == true)
        #expect(state.isError == false)
    }

    @Test func testStreamingState() {
        let state = SessionState.streaming
        #expect(state.isActive == true)
        #expect(state.isError == false)
    }

    @Test func testDisconnectingState() {
        let state = SessionState.disconnecting
        #expect(state.isActive == false)
        #expect(state.isError == false)
    }

    @Test func testErrorState() {
        let state = SessionState.error(.timeout)
        #expect(state.isActive == false)
        #expect(state.isError == true)
    }

    @Test func testStateEquatable() {
        #expect(SessionState.idle == SessionState.idle)
        #expect(SessionState.connecting == SessionState.connecting)
        #expect(SessionState.error(.timeout) == SessionState.error(.timeout))
        #expect(SessionState.error(.timeout) != SessionState.error(.authenticationFailed))
    }
}

// MARK: - Session Error Tests

struct SessionErrorTests {

    @Test func testErrorDescriptions() {
        #expect(SessionError.connectionFailed("test").description.contains("Connection failed"))
        #expect(SessionError.authenticationFailed.description.contains("Authentication"))
        #expect(SessionError.networkError("net").description.contains("Network"))
        #expect(SessionError.timeout.description.contains("timeout"))
        #expect(SessionError.alreadyConnected.description.contains("Already"))
        #expect(SessionError.invalidState.description.contains("Invalid"))
        #expect(SessionError.registrationRequired.description.contains("Registration"))
        #expect(SessionError.versionMismatch.description.contains("Version"))
        #expect(SessionError.remotePlayInUse.description.contains("in use"))
        #expect(SessionError.unknown(999).description.contains("999"))
    }

    @Test func testErrorEquatable() {
        #expect(SessionError.timeout == SessionError.timeout)
        #expect(SessionError.authenticationFailed == SessionError.authenticationFailed)
        #expect(SessionError.connectionFailed("a") == SessionError.connectionFailed("a"))
        #expect(SessionError.connectionFailed("a") != SessionError.connectionFailed("b"))
        #expect(SessionError.unknown(1) == SessionError.unknown(1))
        #expect(SessionError.unknown(1) != SessionError.unknown(2))
    }
}

// MARK: - Host Config Tests

struct HostConfigTests {

    @Test func testInitialization() {
        let registKey = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
                              0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10])
        let morning = Data([0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
                            0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x20])

        let config = HostConfig(
            address: "192.168.1.100",
            registKey: registKey,
            morning: morning,
            isPS5: true,
            nickname: "My PS5"
        )

        #expect(config.address == "192.168.1.100")
        #expect(config.registKey == registKey)
        #expect(config.morning == morning)
        #expect(config.isPS5 == true)
        #expect(config.nickname == "My PS5")
    }

    @Test func testOptionalNickname() {
        let config = HostConfig(
            address: "192.168.1.100",
            registKey: Data(),
            morning: Data(),
            isPS5: false
        )

        #expect(config.nickname == nil)
        #expect(config.isPS5 == false)
    }
}

// MARK: - Stream Config Tests

struct StreamConfigTests {

    @Test func testDefaultConfig() {
        let config = StreamConfig.default

        #expect(config.resolution == .r1080p)
        #expect(config.fps == .fps60)
        #expect(config.codec == .h265)
        #expect(config.autoDowngrade == true)
    }

    @Test func testBalancedConfig() {
        let config = StreamConfig.balanced

        #expect(config.resolution == .r720p)
        #expect(config.fps == .fps60)
        #expect(config.codec == .h265)
    }

    @Test func testVideoProfile() {
        let config = StreamConfig.default
        let profile = config.videoProfile

        #expect(profile.width == 1920)
        #expect(profile.height == 1080)
        #expect(profile.maxFPS == 60)
        #expect(profile.codec == .h265)
    }

    @Test func testCustomBitrate() {
        var config = StreamConfig.default
        config.bitrate = 20_000_000

        let profile = config.videoProfile
        #expect(profile.bitrate == 20_000_000)
    }
}

// MARK: - UT-002: Discovery Error Tests

struct DiscoveryErrorTests {

    @Test func testErrorDescriptions() {
        #expect(DiscoveryError.invalidAddress.errorDescription?.contains("Invalid") == true)
        #expect(DiscoveryError.notRegistered.errorDescription?.contains("not registered") == true)
        #expect(DiscoveryError.invalidRegistrationKey.errorDescription?.contains("Invalid registration") == true)
        #expect(DiscoveryError.notInitialized.errorDescription?.contains("not initialized") == true)
        #expect(DiscoveryError.initializationFailed.errorDescription?.contains("Failed to initialize") == true)
        #expect(DiscoveryError.wakeUpFailed.errorDescription?.contains("Failed to send") == true)
    }
}

// MARK: - Chiaki Types Tests

struct ChiakiTypesTests {

    @Test func testChiakiErrorDescriptions() {
        #expect(ChiakiError.success.description == "Success")
        #expect(ChiakiError.timeout.description.contains("timed out"))
        #expect(ChiakiError.connectionRefused.description.contains("refused"))
        #expect(ChiakiError.hostDown.description.contains("down"))
        #expect(ChiakiError.network.description.contains("Network"))
    }

    @Test func testTargetPlatform() {
        #expect(ChiakiTargetPlatform.ps4Unknown.isPS5 == false)
        #expect(ChiakiTargetPlatform.ps4_10.isPS5 == false)
        #expect(ChiakiTargetPlatform.ps5Unknown.isPS5 == true)
        #expect(ChiakiTargetPlatform.ps5_1.isPS5 == true)

        #expect(ChiakiTargetPlatform.ps4Unknown.isUnknown == true)
        #expect(ChiakiTargetPlatform.ps5Unknown.isUnknown == true)
        #expect(ChiakiTargetPlatform.ps4_10.isUnknown == false)
    }

    @Test func testVideoCodec() {
        #expect(ChiakiVideoCodec.h264.isH265 == false)
        #expect(ChiakiVideoCodec.h264.isHDR == false)

        #expect(ChiakiVideoCodec.h265.isH265 == true)
        #expect(ChiakiVideoCodec.h265.isHDR == false)

        #expect(ChiakiVideoCodec.h265HDR.isH265 == true)
        #expect(ChiakiVideoCodec.h265HDR.isHDR == true)
    }

    @Test func testResolution() {
        #expect(ChiakiResolution.r360p.width == 640)
        #expect(ChiakiResolution.r360p.height == 360)

        #expect(ChiakiResolution.r720p.width == 1280)
        #expect(ChiakiResolution.r720p.height == 720)

        #expect(ChiakiResolution.r1080p.width == 1920)
        #expect(ChiakiResolution.r1080p.height == 1080)
    }

    @Test func testFPS() {
        #expect(ChiakiFPS.fps30.rawValue == 30)
        #expect(ChiakiFPS.fps60.rawValue == 60)
    }

    @Test func testQuitReason() {
        #expect(ChiakiSessionQuitReason.stopped.isError == false)
        #expect(ChiakiSessionQuitReason.streamConnectionRemoteShutdown.isError == false)
        #expect(ChiakiSessionQuitReason.sessionRequestConnectionRefused.isError == true)
        #expect(ChiakiSessionQuitReason.ctrlConnectFailed.isError == true)
    }

    @Test func testLogLevelMask() {
        let all = ChiakiLogLevelMask.all
        #expect(all.contains(.error))
        #expect(all.contains(.warning))
        #expect(all.contains(.info))
        #expect(all.contains(.verbose))
        #expect(all.contains(.debug))

        let production = ChiakiLogLevelMask.production
        #expect(production.contains(.error))
        #expect(production.contains(.warning))
        #expect(production.contains(.info))
        #expect(production.contains(.verbose) == false)
    }
}

// MARK: - Controller Input Tests (IT-003 partial)

struct ControllerInputTests {

    @Test func testDefaultInput() {
        let input = ChiakiControllerInput()

        #expect(input.buttons.isEmpty)
        #expect(input.l2 == 0)
        #expect(input.r2 == 0)
        #expect(input.leftStickX == 0)
        #expect(input.leftStickY == 0)
        #expect(input.rightStickX == 0)
        #expect(input.rightStickY == 0)
    }

    @Test func testButtonFlags() {
        var input = ChiakiControllerInput()

        input.buttons.insert(.cross)
        input.buttons.insert(.moon)
        input.buttons.insert(.l1)

        #expect(input.buttons.contains(.cross))
        #expect(input.buttons.contains(.moon))
        #expect(input.buttons.contains(.l1))
        #expect(input.buttons.contains(.r1) == false)
    }

    @Test func testAnalogInputs() {
        var input = ChiakiControllerInput()

        // Triggers
        input.l2 = 128
        input.r2 = 255

        #expect(input.l2 == 128)
        #expect(input.r2 == 255)

        // Sticks
        input.leftStickX = -32767
        input.leftStickY = 32767
        input.rightStickX = 16000
        input.rightStickY = -16000

        #expect(input.leftStickX == -32767)
        #expect(input.leftStickY == 32767)
        #expect(input.rightStickX == 16000)
        #expect(input.rightStickY == -16000)
    }

    @Test func testMotionInputs() {
        var input = ChiakiControllerInput()

        // Gyro
        input.gyroX = 1.5
        input.gyroY = -0.5
        input.gyroZ = 0.0

        #expect(input.gyroX == 1.5)
        #expect(input.gyroY == -0.5)
        #expect(input.gyroZ == 0.0)

        // Accelerometer
        input.accelX = 0.0
        input.accelY = 0.0
        input.accelZ = -1.0

        #expect(input.accelX == 0.0)
        #expect(input.accelZ == -1.0)

        // Orientation (quaternion)
        input.orientW = 1.0
        #expect(input.orientW == 1.0)
    }

    @Test func testChiakiStateConversion() {
        var input = ChiakiControllerInput()
        input.buttons = [.cross, .r1]
        input.l2 = 100
        input.r2 = 200
        input.leftStickX = 1000
        input.leftStickY = -1000

        let state = input.chiakiState

        #expect(state.buttons == input.buttons.rawValue)
        #expect(state.l2_state == 100)
        #expect(state.r2_state == 200)
        #expect(state.left_x == 1000)
        #expect(state.left_y == -1000)
    }
}

// MARK: - Controller Buttons Tests

struct ControllerButtonsTests {

    @Test func testIndividualButtons() {
        #expect(ChiakiControllerButtons.cross.rawValue == 1 << 0)
        #expect(ChiakiControllerButtons.moon.rawValue == 1 << 1)
        #expect(ChiakiControllerButtons.box.rawValue == 1 << 2)
        #expect(ChiakiControllerButtons.pyramid.rawValue == 1 << 3)
    }

    @Test func testDpad() {
        #expect(ChiakiControllerButtons.dpadLeft.rawValue == 1 << 4)
        #expect(ChiakiControllerButtons.dpadRight.rawValue == 1 << 5)
        #expect(ChiakiControllerButtons.dpadUp.rawValue == 1 << 6)
        #expect(ChiakiControllerButtons.dpadDown.rawValue == 1 << 7)
    }

    @Test func testShoulderButtons() {
        #expect(ChiakiControllerButtons.l1.rawValue == 1 << 8)
        #expect(ChiakiControllerButtons.r1.rawValue == 1 << 9)
        #expect(ChiakiControllerButtons.l3.rawValue == 1 << 10)
        #expect(ChiakiControllerButtons.r3.rawValue == 1 << 11)
    }

    @Test func testSystemButtons() {
        #expect(ChiakiControllerButtons.options.rawValue == 1 << 12)
        #expect(ChiakiControllerButtons.share.rawValue == 1 << 13)
        #expect(ChiakiControllerButtons.touchpad.rawValue == 1 << 14)
        #expect(ChiakiControllerButtons.ps.rawValue == 1 << 15)
    }

    @Test func testOptionSetOperations() {
        var buttons: ChiakiControllerButtons = []

        buttons.insert(.cross)
        buttons.insert(.moon)

        #expect(buttons.contains(.cross))
        #expect(buttons.contains(.moon))

        buttons.remove(.cross)
        #expect(buttons.contains(.cross) == false)
        #expect(buttons.contains(.moon))
    }
}

// MARK: - Registered Host Info Tests

struct RegisteredHostInfoTests {

    @Test func testInitialization() {
        let serverMAC = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])
        let registKey = Data(repeating: 0xAA, count: 16)
        let rpKey = Data(repeating: 0xBB, count: 16)

        let info = RegisteredHostInfo(
            target: .ps5_1,
            serverNickname: "My PS5",
            serverMAC: serverMAC,
            registKey: registKey,
            rpKey: rpKey,
            rpKeyType: 1
        )

        #expect(info.target == .ps5_1)
        #expect(info.serverNickname == "My PS5")
        #expect(info.serverMAC == serverMAC)
        #expect(info.registKey == registKey)
        #expect(info.rpKey == rpKey)
        #expect(info.rpKeyType == 1)
        #expect(info.isPS5 == true)
    }

    @Test func testMACString() {
        let serverMAC = Data([0x01, 0x23, 0x45, 0x67, 0x89, 0xAB])

        let info = RegisteredHostInfo(
            target: .ps4_10,
            serverNickname: "PS4",
            serverMAC: serverMAC,
            registKey: Data(),
            rpKey: Data(),
            rpKeyType: 0
        )

        #expect(info.serverMACString == "01:23:45:67:89:AB")
        #expect(info.isPS5 == false)
    }

    @Test func testCodable() throws {
        let info = RegisteredHostInfo(
            target: .ps5_1,
            serverNickname: "Test",
            serverMAC: Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06]),
            registKey: Data(repeating: 0xAA, count: 16),
            rpKey: Data(repeating: 0xBB, count: 16),
            rpKeyType: 1
        )

        let data = try JSONEncoder().encode(info)
        let decoded = try JSONDecoder().decode(RegisteredHostInfo.self, from: data)

        #expect(decoded.id == info.id)
        #expect(decoded.target == info.target)
        #expect(decoded.serverNickname == info.serverNickname)
        #expect(decoded.serverMAC == info.serverMAC)
    }
}

// MARK: - Video Profile Tests

struct VideoProfileTests {

    @Test func testProfileFromResolutionAndFPS() {
        let profile = ChiakiStreamVideoProfile(
            resolution: .r1080p,
            fps: .fps60,
            codec: .h265
        )

        #expect(profile.width == 1920)
        #expect(profile.height == 1080)
        #expect(profile.maxFPS == 60)
        #expect(profile.codec == .h265)
    }

    @Test func testBitrateCalculation() {
        let profile720p30 = ChiakiStreamVideoProfile(resolution: .r720p, fps: .fps30)
        let profile720p60 = ChiakiStreamVideoProfile(resolution: .r720p, fps: .fps60)

        // 60fps should have higher bitrate than 30fps
        #expect(profile720p60.bitrate > profile720p30.bitrate)
    }

    @Test func testChiakiProfileConversion() {
        let profile = ChiakiStreamVideoProfile(
            resolution: .r1080p,
            fps: .fps60,
            codec: .h265
        )

        let chiakiProfile = profile.chiakiProfile

        #expect(chiakiProfile.width == 1920)
        #expect(chiakiProfile.height == 1080)
        #expect(chiakiProfile.max_fps == 60)
    }
}
