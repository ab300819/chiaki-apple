// SPDX-License-Identifier: AGPL-3.0-only
//
// ChiakiTypes.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Swift-friendly type definitions for Chiaki streaming
// Note: C type conversions will be added when libchiaki is linked

import Foundation

// MARK: - Error Handling

/// Swift wrapper for ChiakiErrorCode
enum ChiakiError: UInt32, Error, CustomStringConvertible {
    case success = 0
    case unknown = 1
    case parseAddr = 2
    case thread = 3
    case memory = 4
    case overflow = 5
    case network = 6
    case connectionRefused = 7
    case hostDown = 8
    case hostUnreach = 9
    case disconnected = 10
    case invalidData = 11
    case bufTooSmall = 12
    case mutexLocked = 13
    case canceled = 14
    case timeout = 15
    case invalidResponse = 16
    case invalidMac = 17
    case uninitialized = 18
    case fecFailed = 19
    case versionMismatch = 20
    case httpNonOk = 21

    var description: String {
        switch self {
        case .success: return "Success"
        case .unknown: return "Unknown error"
        case .parseAddr: return "Failed to parse address"
        case .thread: return "Thread error"
        case .memory: return "Memory allocation error"
        case .overflow: return "Buffer overflow"
        case .network: return "Network error"
        case .connectionRefused: return "Connection refused"
        case .hostDown: return "Host is down"
        case .hostUnreach: return "Host unreachable"
        case .disconnected: return "Disconnected"
        case .invalidData: return "Invalid data"
        case .bufTooSmall: return "Buffer too small"
        case .mutexLocked: return "Mutex locked"
        case .canceled: return "Operation canceled"
        case .timeout: return "Operation timed out"
        case .invalidResponse: return "Invalid response"
        case .invalidMac: return "Invalid MAC address"
        case .uninitialized: return "Not initialized"
        case .fecFailed: return "FEC failed"
        case .versionMismatch: return "Version mismatch"
        case .httpNonOk: return "HTTP non-OK response"
        }
    }
}

// MARK: - Target Platform

/// Swift wrapper for ChiakiTarget - represents PlayStation console type and version
enum ChiakiTargetPlatform: UInt32, Codable {
    case ps4Unknown = 0
    case ps4_8 = 800
    case ps4_9 = 900
    case ps4_10 = 1000
    case ps5Unknown = 1000000
    case ps5_1 = 1000100

    var isPS5: Bool {
        rawValue >= ChiakiTargetPlatform.ps5Unknown.rawValue
    }

    var isUnknown: Bool {
        self == .ps4Unknown || self == .ps5Unknown
    }

    var discoveryPort: UInt16 {
        isPS5 ? 9302 : 987  // CHIAKI_DISCOVERY_PORT_PS5 : CHIAKI_DISCOVERY_PORT_PS4
    }
}

// MARK: - Video Codec

/// Swift wrapper for ChiakiCodec
enum ChiakiVideoCodec: UInt32 {
    case h264 = 0
    case h265 = 1
    case h265HDR = 2

    var isH265: Bool {
        self == .h265 || self == .h265HDR
    }

    var isHDR: Bool {
        self == .h265HDR
    }

    var displayName: String {
        switch self {
        case .h264: return "H.264"
        case .h265: return "H.265"
        case .h265HDR: return "H.265 HDR"
        }
    }
}

// MARK: - Log Level

/// Swift wrapper for ChiakiLogLevel
struct ChiakiLogLevelMask: OptionSet {
    let rawValue: UInt32

    static let error = ChiakiLogLevelMask(rawValue: 1 << 0)
    static let warning = ChiakiLogLevelMask(rawValue: 1 << 1)
    static let info = ChiakiLogLevelMask(rawValue: 1 << 2)
    static let verbose = ChiakiLogLevelMask(rawValue: 1 << 3)
    static let debug = ChiakiLogLevelMask(rawValue: 1 << 4)

    static let all: ChiakiLogLevelMask = [.error, .warning, .info, .verbose, .debug]
    static let production: ChiakiLogLevelMask = [.error, .warning, .info]
}

/// Swift-friendly log level enum
enum ChiakiLogSeverity: UInt32 {
    case debug = 16    // 1 << 4
    case verbose = 8   // 1 << 3
    case info = 4      // 1 << 2
    case warning = 2   // 1 << 1
    case error = 1     // 1 << 0

    var symbol: String {
        switch self {
        case .debug: return "D"
        case .verbose: return "V"
        case .info: return "I"
        case .warning: return "W"
        case .error: return "E"
        }
    }
}

// MARK: - Controller Buttons

/// Swift wrapper for ChiakiControllerButton
struct ChiakiControllerButtons: OptionSet {
    let rawValue: UInt32

    static let cross = ChiakiControllerButtons(rawValue: 1 << 0)
    static let moon = ChiakiControllerButtons(rawValue: 1 << 1)      // Circle
    static let box = ChiakiControllerButtons(rawValue: 1 << 2)       // Square
    static let pyramid = ChiakiControllerButtons(rawValue: 1 << 3)   // Triangle
    static let dpadLeft = ChiakiControllerButtons(rawValue: 1 << 4)
    static let dpadRight = ChiakiControllerButtons(rawValue: 1 << 5)
    static let dpadUp = ChiakiControllerButtons(rawValue: 1 << 6)
    static let dpadDown = ChiakiControllerButtons(rawValue: 1 << 7)
    static let l1 = ChiakiControllerButtons(rawValue: 1 << 8)
    static let r1 = ChiakiControllerButtons(rawValue: 1 << 9)
    static let l3 = ChiakiControllerButtons(rawValue: 1 << 10)
    static let r3 = ChiakiControllerButtons(rawValue: 1 << 11)
    static let options = ChiakiControllerButtons(rawValue: 1 << 12)
    static let share = ChiakiControllerButtons(rawValue: 1 << 13)
    static let touchpad = ChiakiControllerButtons(rawValue: 1 << 14)
    static let ps = ChiakiControllerButtons(rawValue: 1 << 15)

    // Analog triggers (different bit range)
    static let l2 = ChiakiControllerButtons(rawValue: 1 << 16)
    static let r2 = ChiakiControllerButtons(rawValue: 1 << 17)
}

// MARK: - Discovery Host State

/// Swift wrapper for ChiakiDiscoveryHostState
enum ChiakiHostState: UInt32 {
    case unknown = 0
    case ready = 1
    case standby = 2

    var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .ready: return "Ready"
        case .standby: return "Standby"
        }
    }
}

// MARK: - Video Resolution Preset

/// Swift wrapper for ChiakiVideoResolutionPreset
enum ChiakiResolution: UInt32 {
    case r360p = 1
    case r540p = 2
    case r720p = 3
    case r1080p = 4

    var displayName: String {
        switch self {
        case .r360p: return "360p"
        case .r540p: return "540p"
        case .r720p: return "720p"
        case .r1080p: return "1080p"
        }
    }

    var width: UInt32 {
        switch self {
        case .r360p: return 640
        case .r540p: return 960
        case .r720p: return 1280
        case .r1080p: return 1920
        }
    }

    var height: UInt32 {
        switch self {
        case .r360p: return 360
        case .r540p: return 540
        case .r720p: return 720
        case .r1080p: return 1080
        }
    }
}

// MARK: - Video FPS Preset

/// Swift wrapper for ChiakiVideoFPSPreset
enum ChiakiFPS: UInt32 {
    case fps30 = 30
    case fps60 = 60

    var displayName: String {
        "\(rawValue) FPS"
    }
}

// MARK: - Session Events

/// Swift wrapper for ChiakiEventType
enum ChiakiSessionEvent {
    case connected
    case loginPinRequest(pinIncorrect: Bool)
    case holepunch(finished: Bool)
    case nicknameReceived(nickname: String)
    case keyboardOpen
    case keyboardTextChange(text: String)
    case keyboardRemoteClose
    case rumble(left: UInt8, right: UInt8)
    case quit(reason: ChiakiSessionQuitReason, reasonString: String?)
    case triggerEffects
    case motionReset
    case ledColor(r: UInt8, g: UInt8, b: UInt8)
    case playerIndex(index: UInt8)
    case hapticIntensity
    case triggerIntensity
}

// MARK: - Quit Reason

/// Swift wrapper for ChiakiQuitReason
enum ChiakiSessionQuitReason: UInt32 {
    case none = 0
    case stopped = 1
    case sessionRequestUnknown = 2
    case sessionRequestConnectionRefused = 3
    case sessionRequestRPInUse = 4
    case sessionRequestRPCrash = 5
    case sessionRequestRPVersionMismatch = 6
    case ctrlUnknown = 7
    case ctrlConnectFailed = 8
    case ctrlConnectionRefused = 9
    case streamConnectionUnknown = 10
    case streamConnectionRemoteDisconnected = 11
    case streamConnectionRemoteShutdown = 12
    case psnRegistFailed = 13

    var isError: Bool {
        self != .stopped && self != .streamConnectionRemoteShutdown
    }

    var displayString: String {
        switch self {
        case .none: return "None"
        case .stopped: return "Stopped"
        case .sessionRequestUnknown: return "Session request unknown"
        case .sessionRequestConnectionRefused: return "Connection refused"
        case .sessionRequestRPInUse: return "Remote Play in use"
        case .sessionRequestRPCrash: return "Remote Play crashed"
        case .sessionRequestRPVersionMismatch: return "Version mismatch"
        case .ctrlUnknown: return "Control unknown"
        case .ctrlConnectFailed: return "Control connect failed"
        case .ctrlConnectionRefused: return "Control connection refused"
        case .streamConnectionUnknown: return "Stream connection unknown"
        case .streamConnectionRemoteDisconnected: return "Remote disconnected"
        case .streamConnectionRemoteShutdown: return "Remote shutdown"
        case .psnRegistFailed: return "PSN registration failed"
        }
    }
}

// MARK: - Video Profile

/// Swift-friendly video profile configuration
struct ChiakiStreamVideoProfile {
    var width: UInt32
    var height: UInt32
    var maxFPS: UInt32
    var bitrate: UInt32
    var codec: ChiakiVideoCodec

    init(resolution: ChiakiResolution, fps: ChiakiFPS, codec: ChiakiVideoCodec = .h265) {
        self.width = resolution.width
        self.height = resolution.height
        self.maxFPS = fps.rawValue
        self.bitrate = Self.calculateBitrate(resolution: resolution, fps: fps)
        self.codec = codec
    }

    private static func calculateBitrate(resolution: ChiakiResolution, fps: ChiakiFPS) -> UInt32 {
        // Approximate bitrate calculation based on resolution and FPS
        let baseBitrate: UInt32 = switch resolution {
        case .r360p: 2_000_000
        case .r540p: 4_000_000
        case .r720p: 8_000_000
        case .r1080p: 15_000_000
        }
        return fps == .fps60 ? baseBitrate * 3 / 2 : baseBitrate
    }
}

// MARK: - Controller State

/// Swift-friendly controller state wrapper
struct ChiakiControllerInput {
    var buttons: ChiakiControllerButtons = []
    var l2: UInt8 = 0
    var r2: UInt8 = 0
    var leftStickX: Int16 = 0
    var leftStickY: Int16 = 0
    var rightStickX: Int16 = 0
    var rightStickY: Int16 = 0
    var gyroX: Float = 0
    var gyroY: Float = 0
    var gyroZ: Float = 0
    var accelX: Float = 0
    var accelY: Float = 0
    var accelZ: Float = 0
    var orientX: Float = 0
    var orientY: Float = 0
    var orientZ: Float = 0
    var orientW: Float = 1
}

// MARK: - Registered Host

/// Swift-friendly wrapper for registered host credentials
/// Contains credentials needed to connect to a registered PlayStation
struct RegisteredHostInfo: Identifiable, Codable, Equatable {
    let id: UUID
    var target: ChiakiTargetPlatform
    var serverNickname: String
    var serverMAC: Data           // 6 bytes
    var registKey: Data           // 16 bytes (CHIAKI_SESSION_AUTH_SIZE)
    var rpKey: Data               // 16 bytes
    var rpKeyType: UInt32
    var consolePin: UInt32?

    // WiFi AP info (for future PSN Remote Play)
    var apSSID: String?
    var apBSSID: String?
    var apKey: String?
    var apName: String?

    /// Create a new registered host info manually
    init(
        target: ChiakiTargetPlatform,
        serverNickname: String,
        serverMAC: Data,
        registKey: Data,
        rpKey: Data,
        rpKeyType: UInt32,
        consolePin: UInt32? = nil
    ) {
        self.id = UUID()
        self.target = target
        self.serverNickname = serverNickname
        self.serverMAC = serverMAC
        self.registKey = registKey
        self.rpKey = rpKey
        self.rpKeyType = rpKeyType
        self.consolePin = consolePin
    }

    /// Server MAC address as formatted string
    var serverMACString: String {
        serverMAC.map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    /// Whether this is a PS5
    var isPS5: Bool {
        target.isPS5
    }
}

// MARK: - Discovered Host

/// Information about a discovered PlayStation on the network
struct DiscoveredHostInfo: Identifiable, Equatable {
    let id: UUID
    var address: String
    var hostState: ChiakiHostState
    var systemVersion: String?
    var deviceDiscoveryProtocolVersion: String?
    var hostRequestPort: UInt16
    var hostName: String?
    var hostType: String?
    var hostId: String?
    var runningAppTitleId: String?
    var runningAppName: String?

    init(
        address: String,
        hostState: ChiakiHostState = .unknown,
        systemVersion: String? = nil,
        hostRequestPort: UInt16 = 0,
        hostName: String? = nil,
        hostType: String? = nil,
        hostId: String? = nil
    ) {
        self.id = UUID()
        self.address = address
        self.hostState = hostState
        self.systemVersion = systemVersion
        self.hostRequestPort = hostRequestPort
        self.hostName = hostName
        self.hostType = hostType
        self.hostId = hostId
    }

    /// Whether host is available for connection
    var isAvailable: Bool {
        hostState == .ready
    }

    /// Whether host is in standby mode
    var isStandby: Bool {
        hostState == .standby
    }
}

// MARK: - Dual Sense Effect Intensity

/// DualSense adaptive trigger/haptic intensity settings
struct DualSenseIntensity {
    var leftTrigger: UInt8
    var rightTrigger: UInt8
    var haptic: UInt8

    static var `default`: DualSenseIntensity {
        DualSenseIntensity(leftTrigger: 255, rightTrigger: 255, haptic: 255)
    }

    static var disabled: DualSenseIntensity {
        DualSenseIntensity(leftTrigger: 0, rightTrigger: 0, haptic: 0)
    }
}

// MARK: - C Type Conversion Extensions

extension ChiakiStreamVideoProfile {
    /// Convert to C ChiakiConnectVideoProfile
    var chiakiProfile: ChiakiConnectVideoProfile {
        ChiakiConnectVideoProfile(
            width: width,
            height: height,
            max_fps: maxFPS,
            bitrate: bitrate,
            codec: ChiakiCodec(rawValue: codec.rawValue)
        )
    }
}

extension ChiakiControllerInput {
    /// Convert to C ChiakiControllerState
    var chiakiState: ChiakiControllerState {
        var state = ChiakiControllerState()
        state.buttons = buttons.rawValue
        state.l2_state = l2
        state.r2_state = r2
        state.left_x = leftStickX
        state.left_y = leftStickY
        state.right_x = rightStickX
        state.right_y = rightStickY
        state.gyro_x = gyroX
        state.gyro_y = gyroY
        state.gyro_z = gyroZ
        state.accel_x = accelX
        state.accel_y = accelY
        state.accel_z = accelZ
        state.orient_x = orientX
        state.orient_y = orientY
        state.orient_z = orientZ
        state.orient_w = orientW
        return state
    }
}

extension ChiakiError {
    /// Create from C ChiakiErrorCode
    static func from(_ code: ChiakiErrorCode) -> ChiakiError? {
        ChiakiError(rawValue: code.rawValue)
    }
}

extension ChiakiSessionQuitReason {
    /// Create from C ChiakiQuitReason
    static func from(_ reason: ChiakiQuitReason) -> ChiakiSessionQuitReason? {
        ChiakiSessionQuitReason(rawValue: reason.rawValue)
    }
}

extension ChiakiLogSeverity {
    /// Create from C ChiakiLogLevel
    static func from(_ level: ChiakiLogLevel) -> ChiakiLogSeverity {
        ChiakiLogSeverity(rawValue: level.rawValue) ?? .info
    }
}
