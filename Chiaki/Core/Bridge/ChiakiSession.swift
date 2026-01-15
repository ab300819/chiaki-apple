// SPDX-License-Identifier: AGPL-3.0-only
//
// ChiakiSession.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Swift wrapper for libchiaki session management
// Handles connection, video/audio callbacks, and controller input

import Foundation
import CoreMedia

// MARK: - Session State

/// Session state enumeration
enum SessionState: Equatable {
    case idle
    case connecting
    case connected
    case streaming
    case disconnecting
    case error(SessionError)

    var isActive: Bool {
        switch self {
        case .connecting, .connected, .streaming:
            return true
        default:
            return false
        }
    }

    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}

// MARK: - Session Error

/// Session error enumeration
enum SessionError: Error, Equatable, CustomStringConvertible {
    case connectionFailed(String)
    case authenticationFailed
    case networkError(String)
    case timeout
    case alreadyConnected
    case invalidState
    case registrationRequired
    case versionMismatch
    case remotePlayInUse
    case unknown(Int32)

    var description: String {
        switch self {
        case .connectionFailed(let msg):
            return "Connection failed: \(msg)"
        case .authenticationFailed:
            return "Authentication failed"
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .timeout:
            return "Connection timeout"
        case .alreadyConnected:
            return "Already connected"
        case .invalidState:
            return "Invalid state"
        case .registrationRequired:
            return "Registration required"
        case .versionMismatch:
            return "Version mismatch"
        case .remotePlayInUse:
            return "Remote Play is already in use"
        case .unknown(let code):
            return "Unknown error: \(code)"
        }
    }

    static func from(quitReason: ChiakiSessionQuitReason) -> SessionError {
        switch quitReason {
        case .sessionRequestConnectionRefused:
            return .connectionFailed("Connection refused")
        case .sessionRequestRPInUse:
            return .remotePlayInUse
        case .sessionRequestRPVersionMismatch:
            return .versionMismatch
        case .ctrlConnectFailed, .ctrlConnectionRefused:
            return .connectionFailed("Control connection failed")
        case .psnRegistFailed:
            return .registrationRequired
        default:
            return .unknown(Int32(quitReason.rawValue))
        }
    }
}

// MARK: - Host Configuration

/// Host connection configuration
struct HostConfig {
    let address: String
    let registKey: Data      // 16 bytes
    let morning: Data        // 16 bytes
    let isPS5: Bool
    let nickname: String?

    init(address: String, registKey: Data, morning: Data, isPS5: Bool, nickname: String? = nil) {
        self.address = address
        self.registKey = registKey
        self.morning = morning
        self.isPS5 = isPS5
        self.nickname = nickname
    }
}

// MARK: - Stream Configuration

/// Stream quality configuration
struct StreamConfig {
    var resolution: ChiakiResolution
    var fps: ChiakiFPS
    var codec: ChiakiVideoCodec
    var bitrate: UInt32?
    var autoDowngrade: Bool

    static var `default`: StreamConfig {
        StreamConfig(
            resolution: .r1080p,
            fps: .fps60,
            codec: .h265,
            bitrate: nil,
            autoDowngrade: true
        )
    }

    static var balanced: StreamConfig {
        StreamConfig(
            resolution: .r720p,
            fps: .fps60,
            codec: .h265,
            bitrate: nil,
            autoDowngrade: true
        )
    }

    var videoProfile: ChiakiStreamVideoProfile {
        var profile = ChiakiStreamVideoProfile(resolution: resolution, fps: fps, codec: codec)
        if let bitrate = bitrate {
            profile.bitrate = bitrate
        }
        return profile
    }
}

// MARK: - Chiaki Session

/// Main session wrapper for libchiaki
/// Handles connection lifecycle, video/audio callbacks, and controller input
@Observable
final class ChiakiSessionWrapper {
    // MARK: - Properties

    private(set) var state: SessionState = .idle
    private(set) var serverNickname: String?
    private(set) var playerIndex: UInt8 = 0

    private var session: UnsafeMutablePointer<ChiakiSession>?
    private var chiakiLog: UnsafeMutablePointer<ChiakiLog>?

    private let sessionLock = NSLock()
    private let callbackQueue = DispatchQueue(label: "chiaki.session.callback", qos: .userInteractive)

    // Video/Audio bridges
    private var videoDecoderBridge: VideoDecoderBridge?
    private var audioPlayerBridge: AudioPlayerBridge?
    private var streamStatistics: StreamStatistics?

    // Configuration
    private var hostConfig: HostConfig?
    private var streamConfig: StreamConfig = .default

    // MARK: - Callbacks

    /// Called when session state changes
    var onStateChanged: ((SessionState) -> Void)?

    /// Called when login PIN is requested
    var onLoginPinRequest: ((Bool) -> Void)?

    /// Called when rumble feedback is triggered
    var onRumble: ((UInt8, UInt8) -> Void)?

    /// Called when LED color changes
    var onLEDColor: ((UInt8, UInt8, UInt8) -> Void)?

    /// Called when keyboard opens
    var onKeyboardOpen: (() -> Void)?

    /// Called when keyboard text changes
    var onKeyboardTextChange: ((String) -> Void)?

    // MARK: - Initialization

    init() {
        setupChiakiLog()
        logInfo("ChiakiSessionWrapper: Initialized")
    }

    deinit {
        disconnect()
        cleanupChiakiLog()
        logInfo("ChiakiSessionWrapper: Deinitialized")
    }

    // MARK: - Configuration

    /// Set video decoder bridge for decoded frame output
    func setVideoDecoderBridge(_ bridge: VideoDecoderBridge) {
        self.videoDecoderBridge = bridge
    }

    /// Set audio player bridge for audio output
    func setAudioPlayerBridge(_ bridge: AudioPlayerBridge) {
        self.audioPlayerBridge = bridge
    }

    /// Set stream statistics tracker
    func setStreamStatistics(_ statistics: StreamStatistics) {
        self.streamStatistics = statistics
    }

    /// Configure stream quality
    func configure(stream: StreamConfig) {
        self.streamConfig = stream
    }

    // MARK: - Connection

    /// Connect to PlayStation host
    /// - Parameters:
    ///   - host: Host configuration
    ///   - psnAccountId: Optional PSN account ID (8 bytes)
    func connect(to host: HostConfig, psnAccountId: Data? = nil) throws {
        sessionLock.lock()
        defer { sessionLock.unlock() }

        guard state == .idle || state.isError else {
            throw SessionError.alreadyConnected
        }

        self.hostConfig = host

        // Allocate session
        session = UnsafeMutablePointer<ChiakiSession>.allocate(capacity: 1)
        guard let session = session else {
            throw SessionError.connectionFailed("Failed to allocate session")
        }

        // Setup connect info
        var connectInfo = ChiakiConnectInfo()
        connectInfo.ps5 = host.isPS5

        // Set host address
        let hostCString = host.address.cString(using: .utf8)!
        connectInfo.host = UnsafePointer(strdup(hostCString))

        // Set regist key (16 bytes)
        host.registKey.withUnsafeBytes { ptr in
            guard let baseAddress = ptr.baseAddress else { return }
            withUnsafeMutableBytes(of: &connectInfo.regist_key) { destPtr in
                destPtr.copyMemory(from: UnsafeRawBufferPointer(start: baseAddress, count: min(16, host.registKey.count)))
            }
        }

        // Set morning (16 bytes)
        host.morning.withUnsafeBytes { ptr in
            guard let baseAddress = ptr.baseAddress else { return }
            withUnsafeMutableBytes(of: &connectInfo.morning) { destPtr in
                destPtr.copyMemory(from: UnsafeRawBufferPointer(start: baseAddress, count: min(16, host.morning.count)))
            }
        }

        // Set video profile
        let profile = streamConfig.videoProfile.chiakiProfile
        connectInfo.video_profile = profile
        connectInfo.video_profile_auto_downgrade = streamConfig.autoDowngrade

        // Set PSN account ID if provided
        if let accountId = psnAccountId, accountId.count == 8 {
            accountId.withUnsafeBytes { ptr in
                guard let baseAddress = ptr.baseAddress else { return }
                withUnsafeMutableBytes(of: &connectInfo.psn_account_id) { destPtr in
                    destPtr.copyMemory(from: UnsafeRawBufferPointer(start: baseAddress, count: 8))
                }
            }
        }

        // Other settings
        connectInfo.enable_keyboard = true
        connectInfo.enable_dualsense = true

        // Initialize session
        let initResult = chiaki_session_init(session, &connectInfo, chiakiLog)

        // Free host string
        free(UnsafeMutablePointer(mutating: connectInfo.host))

        guard initResult == CHIAKI_ERR_SUCCESS else {
            session.deallocate()
            self.session = nil
            let error = ChiakiError.from(initResult) ?? .unknown
            throw SessionError.connectionFailed(error.description)
        }

        // Setup callbacks
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        chiaki_session_set_event_cb(session, sessionEventCallback, selfPointer)
        chiaki_session_set_video_sample_cb(session, videoSampleCallback, selfPointer)

        // Setup audio sink
        var audioSink = ChiakiAudioSink()
        audioSink.user = selfPointer
        audioSink.header_cb = audioHeaderCallback
        audioSink.frame_cb = audioFrameCallback
        chiaki_session_set_audio_sink(session, &audioSink)

        // Update state
        updateState(.connecting)

        // Start session
        let startResult = chiaki_session_start(session)
        guard startResult == CHIAKI_ERR_SUCCESS else {
            chiaki_session_fini(session)
            session.deallocate()
            self.session = nil
            updateState(.error(.connectionFailed("Failed to start session")))
            let error = ChiakiError.from(startResult) ?? .unknown
            throw SessionError.connectionFailed(error.description)
        }

        logInfo("ChiakiSessionWrapper: Connecting to \(host.address)")
    }

    /// Disconnect from host
    func disconnect() {
        sessionLock.lock()
        defer { sessionLock.unlock() }

        guard let session = session else { return }

        updateState(.disconnecting)

        chiaki_session_stop(session)
        chiaki_session_join(session)
        chiaki_session_fini(session)
        session.deallocate()
        self.session = nil

        // Cleanup bridges
        audioPlayerBridge?.shutdown()
        streamStatistics?.sessionEnded()

        updateState(.idle)
        logInfo("ChiakiSessionWrapper: Disconnected")
    }

    // MARK: - Controller Input

    /// Send controller state to PlayStation
    func sendControllerState(_ input: ChiakiControllerInput) {
        sessionLock.lock()
        guard let session = session, state == .streaming else {
            sessionLock.unlock()
            return
        }
        sessionLock.unlock()

        var controllerState = input.chiakiState
        chiaki_session_set_controller_state(session, &controllerState)
    }

    // MARK: - Login PIN

    /// Submit login PIN (for accounts with parental controls or passwords)
    func submitLoginPin(_ pin: String) {
        sessionLock.lock()
        guard let session = session else {
            sessionLock.unlock()
            return
        }
        sessionLock.unlock()

        let pinData = pin.data(using: .utf8) ?? Data()
        pinData.withUnsafeBytes { ptr in
            guard let baseAddress = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            chiaki_session_set_login_pin(session, baseAddress, pinData.count)
        }

        logInfo("ChiakiSessionWrapper: Login PIN submitted")
    }

    // MARK: - Keyboard

    /// Set keyboard text response
    func setKeyboardText(_ text: String) {
        sessionLock.lock()
        guard let session = session else {
            sessionLock.unlock()
            return
        }
        sessionLock.unlock()

        chiaki_session_keyboard_set_text(session, text)
    }

    /// Accept keyboard input
    func acceptKeyboard() {
        sessionLock.lock()
        guard let session = session else {
            sessionLock.unlock()
            return
        }
        sessionLock.unlock()

        chiaki_session_keyboard_accept(session)
    }

    /// Reject keyboard input
    func rejectKeyboard() {
        sessionLock.lock()
        guard let session = session else {
            sessionLock.unlock()
            return
        }
        sessionLock.unlock()

        chiaki_session_keyboard_reject(session)
    }

    // MARK: - System Commands

    /// Put PlayStation into rest mode
    func goToBed() {
        sessionLock.lock()
        guard let session = session else {
            sessionLock.unlock()
            return
        }
        sessionLock.unlock()

        chiaki_session_goto_bed(session)
        logInfo("ChiakiSessionWrapper: Sent go to bed command")
    }

    /// Go to PlayStation home screen
    func goHome() {
        sessionLock.lock()
        guard let session = session else {
            sessionLock.unlock()
            return
        }
        sessionLock.unlock()

        chiaki_session_go_home(session)
    }

    /// Toggle microphone mute
    func toggleMicrophone(muted: Bool) {
        sessionLock.lock()
        guard let session = session else {
            sessionLock.unlock()
            return
        }
        sessionLock.unlock()

        chiaki_session_toggle_microphone(session, muted)
    }

    // MARK: - Private Methods

    private func setupChiakiLog() {
        chiakiLog = UnsafeMutablePointer<ChiakiLog>.allocate(capacity: 1)
        guard let log = chiakiLog else { return }

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        chiaki_log_init(log, ChiakiLogLevelMask.all.rawValue, chiakiLogCallback, selfPointer)
    }

    private func cleanupChiakiLog() {
        guard let log = chiakiLog else { return }
        // ChiakiLog doesn't have a fini function - it's a simple struct
        log.deallocate()
        chiakiLog = nil
    }

    private func updateState(_ newState: SessionState) {
        state = newState
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onStateChanged?(newState)
        }
    }

    // MARK: - Event Handling

    fileprivate func handleEvent(_ event: ChiakiEvent) {
        switch event.type {
        case CHIAKI_EVENT_CONNECTED:
            handleConnected()

        case CHIAKI_EVENT_LOGIN_PIN_REQUEST:
            handleLoginPinRequest(pinIncorrect: event.login_pin_request.pin_incorrect)

        case CHIAKI_EVENT_NICKNAME_RECEIVED:
            handleNicknameReceived(event)

        case CHIAKI_EVENT_RUMBLE:
            handleRumble(left: event.rumble.left, right: event.rumble.right)

        case CHIAKI_EVENT_LED_COLOR:
            handleLEDColor(
                r: event.led_state.0,
                g: event.led_state.1,
                b: event.led_state.2
            )

        case CHIAKI_EVENT_PLAYER_INDEX:
            handlePlayerIndex(event.player_index)

        case CHIAKI_EVENT_KEYBOARD_OPEN:
            handleKeyboardOpen()

        case CHIAKI_EVENT_KEYBOARD_TEXT_CHANGE:
            handleKeyboardTextChange(event)

        case CHIAKI_EVENT_KEYBOARD_REMOTE_CLOSE:
            // Keyboard closed by remote
            break

        case CHIAKI_EVENT_QUIT:
            handleQuit(event.quit)

        default:
            logVerbose("ChiakiSessionWrapper: Unhandled event type: \(event.type.rawValue)")
        }
    }

    private func handleConnected() {
        updateState(.streaming)
        streamStatistics?.sessionStarted()

        // Start audio player
        do {
            try audioPlayerBridge?.start()
        } catch {
            logError("ChiakiSessionWrapper: Failed to start audio player: \(error)")
        }

        logInfo("ChiakiSessionWrapper: Connected and streaming")
    }

    private func handleLoginPinRequest(pinIncorrect: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.onLoginPinRequest?(pinIncorrect)
        }
        logInfo("ChiakiSessionWrapper: Login PIN requested (incorrect: \(pinIncorrect))")
    }

    private func handleNicknameReceived(_ event: ChiakiEvent) {
        let nickname = withUnsafePointer(to: event.server_nickname) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: 0x20) { charPtr in
                String(cString: charPtr)
            }
        }
        serverNickname = nickname
        logInfo("ChiakiSessionWrapper: Server nickname: \(nickname)")
    }

    private func handleRumble(left: UInt8, right: UInt8) {
        DispatchQueue.main.async { [weak self] in
            self?.onRumble?(left, right)
        }
    }

    private func handleLEDColor(r: UInt8, g: UInt8, b: UInt8) {
        DispatchQueue.main.async { [weak self] in
            self?.onLEDColor?(r, g, b)
        }
    }

    private func handlePlayerIndex(_ index: UInt8) {
        playerIndex = index
        logInfo("ChiakiSessionWrapper: Player index: \(index)")
    }

    private func handleKeyboardOpen() {
        DispatchQueue.main.async { [weak self] in
            self?.onKeyboardOpen?()
        }
    }

    private func handleKeyboardTextChange(_ event: ChiakiEvent) {
        guard let textPtr = event.keyboard.text_str else { return }
        let text = String(cString: textPtr)
        DispatchQueue.main.async { [weak self] in
            self?.onKeyboardTextChange?(text)
        }
    }

    private func handleQuit(_ quitEvent: ChiakiQuitEvent) {
        let reason = ChiakiSessionQuitReason.from(quitEvent.reason) ?? .none
        let reasonStr = quitEvent.reason_str.map { String(cString: $0) }

        if reason.isError {
            let error = SessionError.from(quitReason: reason)
            updateState(.error(error))
            logError("ChiakiSessionWrapper: Quit with error - \(reason.displayString): \(reasonStr ?? "")")
        } else {
            updateState(.idle)
            logInfo("ChiakiSessionWrapper: Quit normally - \(reason.displayString)")
        }
    }

    // MARK: - Video Handling

    fileprivate func handleVideoSample(
        buf: UnsafeMutablePointer<UInt8>,
        bufSize: Int,
        framesLost: Int32,
        frameRecovered: Bool
    ) -> Bool {
        // Update statistics
        streamStatistics?.recordVideoFrame(size: bufSize, wasDropped: framesLost > 0)

        // Forward to video decoder bridge
        // The video data needs NAL unit parsing before being sent to VideoToolbox
        // This is handled by the VideoDecoderBridge
        videoDecoderBridge?.receiveFrame(buf, size: bufSize, timestamp: 0)

        return true
    }

    // MARK: - Audio Handling

    fileprivate func handleAudioHeader(_ header: ChiakiAudioHeader) {
        // Configure audio player with stream parameters
        audioPlayerBridge?.configure(
            sampleRate: Double(header.rate),
            channelCount: UInt32(header.channels)
        )

        logInfo("ChiakiSessionWrapper: Audio header - \(header.channels)ch, \(header.rate)Hz, frameSize: \(header.frame_size)")
    }

    fileprivate func handleAudioFrame(buf: UnsafePointer<UInt8>, bufSize: Int) {
        // Audio data is Opus encoded, needs decoding
        // For now, assume it's already decoded PCM Int16
        let int16Ptr = buf.withMemoryRebound(to: Int16.self, capacity: bufSize / 2) { $0 }
        let frameCount = bufSize / 2 / 2  // bufSize / sizeof(Int16) / channels

        audioPlayerBridge?.receiveAudio(samples: int16Ptr, frameCount: frameCount)
    }
}

// MARK: - C Callbacks

private func sessionEventCallback(
    event: UnsafeMutablePointer<ChiakiEvent>?,
    userData: UnsafeMutableRawPointer?
) {
    guard let event = event, let userData = userData else { return }

    let session = Unmanaged<ChiakiSessionWrapper>.fromOpaque(userData).takeUnretainedValue()

    // Process event - copy data since event pointer is only valid during callback
    let eventCopy = event.pointee
    DispatchQueue.main.async {
        session.handleEvent(eventCopy)
    }
}

private func videoSampleCallback(
    buf: UnsafeMutablePointer<UInt8>?,
    bufSize: Int,
    framesLost: Int32,
    frameRecovered: Bool,
    userData: UnsafeMutableRawPointer?
) -> Bool {
    guard let buf = buf, let userData = userData else { return false }

    let session = Unmanaged<ChiakiSessionWrapper>.fromOpaque(userData).takeUnretainedValue()
    return session.handleVideoSample(buf: buf, bufSize: bufSize, framesLost: framesLost, frameRecovered: frameRecovered)
}

private func audioHeaderCallback(
    header: UnsafeMutablePointer<ChiakiAudioHeader>?,
    userData: UnsafeMutableRawPointer?
) {
    guard let header = header, let userData = userData else { return }

    let session = Unmanaged<ChiakiSessionWrapper>.fromOpaque(userData).takeUnretainedValue()
    session.handleAudioHeader(header.pointee)
}

private func audioFrameCallback(
    buf: UnsafeMutablePointer<UInt8>?,
    bufSize: Int,
    userData: UnsafeMutableRawPointer?
) {
    guard let buf = buf, let userData = userData else { return }

    let session = Unmanaged<ChiakiSessionWrapper>.fromOpaque(userData).takeUnretainedValue()
    session.handleAudioFrame(buf: buf, bufSize: bufSize)
}

private func chiakiLogCallback(
    level: ChiakiLogLevel,
    msg: UnsafePointer<CChar>?,
    userData: UnsafeMutableRawPointer?
) {
    guard let msg = msg else { return }

    let message = String(cString: msg)
    let severity = ChiakiLogSeverity.from( level)

    switch severity {
    case .error:
        logError("[libchiaki] \(message)")
    case .warning:
        logWarning("[libchiaki] \(message)")
    case .info:
        logInfo("[libchiaki] \(message)")
    case .verbose:
        logVerbose("[libchiaki] \(message)")
    case .debug:
        logDebug("[libchiaki] \(message)")
    }
}
