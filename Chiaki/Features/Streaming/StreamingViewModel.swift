// SPDX-License-Identifier: AGPL-3.0-only
//
// StreamingViewModel.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// ViewModel for streaming view, connecting UI to ChiakiSessionWrapper

import Foundation
import Observation
import SwiftUI
import Combine

@Observable
@MainActor
final class StreamingViewModel {
    // MARK: - Connection State

    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case streaming
        case reconnecting
        case error(String)

        var isActive: Bool {
            switch self {
            case .connecting, .connected, .streaming, .reconnecting:
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Published Properties

    private(set) var state: ConnectionState = .disconnected
    var isOverlayVisible: Bool = true

    // Playback controls
    var volume: Double = 1.0
    var displayMode: StreamSettings.DisplayMode = .normal
    var zoomFactor: Double = 1.0
    var isControlMenuVisible: Bool = false
    var videoPreset: StreamSettings.VideoPreset = .default

    // Microphone controls
    var isMicEnabled: Bool = false
    var isMicMuted: Bool = true

    /// Called when connection is established
    var onConnected: (() -> Void)?

    let pipManager = PiPManager()
    let statsManager: StreamStatsManager
    private let inputMapper = ControllerInputMapper()

    // MARK: - Internal state
    
    let host: ConsoleHost
    private let session: ChiakiSessionWrapper
    private let statistics: StreamStatistics
    private let videoDecoderBridge: VideoDecoderBridge
    private let audioPlayerBridge: AudioPlayerBridge

    private var statsUpdateTimer: Timer?
    private var videoRenderer: MetalVideoRenderer?

    /// Current controller state (accumulated from multiple input events)
    private var currentControllerState = ChiakiControllerInput()
    private var lastSettings: StreamSettings?
    private var lastIsRemote: Bool = false

    // MARK: - Initialization

    init(host: ConsoleHost) {
        self.host = host
        self.session = ChiakiSessionWrapper()
        self.statistics = StreamStatistics()
        self.videoDecoderBridge = VideoDecoderBridge()
        self.audioPlayerBridge = AudioPlayerBridge()
        self.statsManager = StreamStatsManager(statistics: statistics, session: session)

        setupSession()
        setupNetworkMonitoring()
        Logger.session.info("StreamingViewModel initialized for \(host.nickname)")
    }
    
    private func setupNetworkMonitoring() {
        // Observe network changes for auto-reconnect
        _ = withObservationTracking {
            NetworkMonitor.shared.isConnected
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.handleNetworkStatusChange()
            }
        }
    }

    private func handleNetworkStatusChange() {
        let isConnected = NetworkMonitor.shared.isConnected
        
        if !isConnected && state == .streaming {
            Logger.session.warning("Network connection lost during streaming")
            state = .reconnecting
        } else if isConnected && state == .reconnecting {
            Logger.session.info("Network restored, attempting auto-reconnect")
            if let settings = lastSettings {
                connect(settings: settings, isRemote: lastIsRemote)
            }
        }
        
        // Setup next observation
        setupNetworkMonitoring()
    }

    // Note: Timer invalidation handled in disconnect() which should be called before deinit

    // MARK: - Setup

    private func setupSession() {
        // Configure bridges
        session.setVideoDecoderBridge(videoDecoderBridge)
        session.setAudioPlayerBridge(audioPlayerBridge)
        session.setStreamStatistics(statistics)

        // Handle session state changes
        session.onStateChanged = { [weak self] newState in
            Task { @MainActor in
                self?.handleSessionStateChange(newState)
            }
        }

        // Handle login PIN request
        session.onLoginPinRequest = { [weak self] pinIncorrect in
            Task { @MainActor in
                self?.handleLoginPinRequest(pinIncorrect: pinIncorrect)
            }
        }

        // Handle rumble feedback
        session.onRumble = { [weak self] left, right in
            Task { @MainActor in
                self?.handleRumble(left: left, right: right)
            }
        }
    }

    /// Set the video renderer for decoded frame output
    func setVideoRenderer(_ renderer: MetalVideoRenderer) {
        self.videoRenderer = renderer
        videoDecoderBridge.setRenderer(renderer)

        renderer.onFrameSubmitted = { [weak self] pixelBuffer in
            self?.pipManager.enqueue(pixelBuffer)
        }
    }

    // MARK: - Connection

    /// Connect to the PlayStation host
    func connect(settings: StreamSettings, isRemote: Bool = false) {
        lastSettings = settings
        lastIsRemote = isRemote
        
        guard !state.isActive || state == .reconnecting else {
            Logger.session.warning("Cannot connect: already active")
            return
        }

        state = .connecting
        Logger.session.info("Connecting to \(host.nickname) at \(host.address)")

        // Verify host has registration data
        guard !host.registKey.isEmpty else {
            state = .error("Host not registered")
            Logger.session.error("Connection failed: host not registered")
            return
        }

        let hostConfig = HostConfig(
            address: host.address,
            registKey: host.registKey,
            morning: host.rpKey,
            isPS5: host.isPS5,
            nickname: host.nickname
        )

        let profile = isRemote ? settings.remoteProfile : settings.localProfile

        // Configure video based on resolution setting
        let videoCodec: ChiakiVideoCodec = settings.codec == .h265 ? .h265 : .h264
        
        videoDecoderBridge.configure(
            codec: videoCodec,
            width: Int32(profile.resolution.width),
            height: Int32(profile.resolution.height)
        )

        // Start connection
        do {
            try session.connect(to: hostConfig)
            startStatsUpdate()
        } catch {
            state = .error(error.localizedDescription)
            Logger.session.error("Connection failed: \(error)")
        }
    }

    /// Disconnect from the host
    func disconnect() {
        statsUpdateTimer?.invalidate()
        statsUpdateTimer = nil

        session.disconnect()
        state = .disconnected

        Logger.session.info("Disconnected from \(host.nickname)")
    }

    // MARK: - Input

    /// Send controller input to the session
    func sendControllerInput(_ input: ChiakiControllerInput) {
        guard state == .streaming else { return }
        session.sendControllerState(input)
    }

    /// Handle virtual controller input
    func handleInput(_ input: VirtualControllerInput) {
        switch input {
        case .leftStick(let x, let y):
            // Convert 0-1 range to Int16 range (-32767 to 32767)
            currentControllerState.leftStickX = Int16(clamping: Int((x * 2 - 1) * 32767))
            currentControllerState.leftStickY = Int16(clamping: Int((y * 2 - 1) * 32767))

        case .rightStick(let x, let y):
            currentControllerState.rightStickX = Int16(clamping: Int((x * 2 - 1) * 32767))
            currentControllerState.rightStickY = Int16(clamping: Int((y * 2 - 1) * 32767))

        case .button(let button, let pressed):
            let chiakiButton = inputMapper.map(button)
            if pressed {
                currentControllerState.buttons.insert(chiakiButton)
                // Handle L2/R2 as analog triggers
                if button == .l2 {
                    currentControllerState.l2 = 255
                } else if button == .r2 {
                    currentControllerState.r2 = 255
                }
            } else {
                currentControllerState.buttons.remove(chiakiButton)
                if button == .l2 {
                    currentControllerState.l2 = 0
                } else if button == .r2 {
                    currentControllerState.r2 = 0
                }
            }
        }

        sendControllerInput(currentControllerState)
    }

    // MARK: - UI Actions

    /// Toggle overlay visibility
    func toggleOverlay() {
        withAnimation(.snappy) {
            isOverlayVisible.toggle()
        }
    }

    /// Toggle control menu visibility
    func toggleControlMenu() {
        withAnimation(.snappy) {
            isControlMenuVisible.toggle()
        }
    }

    // MARK: - Playback Controls

    /// Set audio volume (0.0 - 1.0)
    func setVolume(_ newVolume: Double) {
        volume = max(0.0, min(1.0, newVolume))
        audioPlayerBridge.setVolume(Float(volume))
    }

    /// Set video display mode
    func setDisplayMode(_ mode: StreamSettings.DisplayMode) {
        displayMode = mode
        videoRenderer?.displayMode = mode.toVideoDisplayMode
    }

    /// Set zoom factor (1.0 - 2.0, only used in zoom mode)
    func setZoomFactor(_ factor: Double) {
        zoomFactor = max(1.0, min(2.0, factor))
        videoRenderer?.zoomFactor = Float(zoomFactor)
    }

    /// Set video rendering preset
    func setVideoPreset(_ preset: StreamSettings.VideoPreset) {
        videoPreset = preset
        // TODO: Apply preset to video renderer when libplacebo integration is added
        Logger.session.info("Video preset changed to: \(preset.rawValue)")
    }

    /// Toggle microphone mute state
    func toggleMic() {
        guard isMicEnabled else { return }
        isMicMuted.toggle()
        session.toggleMicrophone(muted: isMicMuted)
        Logger.session.info("Microphone \(isMicMuted ? "muted" : "unmuted")")
    }

    /// Apply settings from SettingsStore
    func applySettings(from settings: StreamSettings) {
        volume = settings.volume
        displayMode = settings.displayMode
        zoomFactor = settings.zoomFactor

        audioPlayerBridge.setVolume(Float(volume))
        videoRenderer?.displayMode = displayMode.toVideoDisplayMode
        videoRenderer?.zoomFactor = Float(zoomFactor)
        videoRenderer?.setColorSpace(settings.colorSpace.rawValue)
    }

    /// Submit login PIN
    func submitLoginPin(_ pin: String) {
        session.submitLoginPin(pin)
    }

    /// Put PlayStation into rest mode
    func goToBed() {
        session.goToBed()
    }

    /// Go to PlayStation home screen
    func goHome() {
        session.goHome()
    }

    // MARK: - State Handling

    private func handleSessionStateChange(_ sessionState: SessionState) {
        switch sessionState {
        case .idle:
            state = .disconnected
        case .connecting:
            state = .connecting
        case .connected:
            state = .connected
        case .streaming:
            state = .streaming
            onConnected?()
        case .disconnecting:
            state = .disconnected
        case .error(let error):
            state = .error(error.description)
        }
    }

    private func handleLoginPinRequest(pinIncorrect: Bool) {
        // TODO: Show PIN entry UI
        Logger.session.info("Login PIN requested (incorrect: \(pinIncorrect))")
    }

    private func handleRumble(left: UInt8, right: UInt8) {
        // TODO: Forward to controller haptics
        Logger.controller.debug("Rumble: L=\(left) R=\(right)")
    }

    // MARK: - Statistics Update

    private func startStatsUpdate() {
        statsUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.statsManager.update()
            }
        }
    }
}

// MARK: - DisplayMode Conversion

extension StreamSettings.DisplayMode {
    /// Convert to VideoDisplayMode for MetalVideoRenderer
    var toVideoDisplayMode: VideoDisplayMode {
        switch self {
        case .normal: return .normal
        case .stretch: return .stretch
        case .zoom: return .zoom
        }
    }
}
