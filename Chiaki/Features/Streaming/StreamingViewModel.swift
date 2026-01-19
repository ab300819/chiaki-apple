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
        case error(String)

        var isActive: Bool {
            switch self {
            case .connecting, .connected, .streaming:
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Published Properties

    private(set) var state: ConnectionState = .disconnected
    var isOverlayVisible: Bool = true

    // Stream statistics (from StreamStatistics)
    var currentResolution: String = "1080p"
    var currentFrameRate: Double = 0
    var latency: Double = 0
    var bitrate: Double = 0
    var connectionQuality: ConnectionQuality = .unknown

    // MARK: - Private Properties

    private let host: ConsoleHost
    private let session: ChiakiSessionWrapper
    private let statistics: StreamStatistics
    private let videoDecoderBridge: VideoDecoderBridge
    private let audioPlayerBridge: AudioPlayerBridge

    private var statsUpdateTimer: Timer?
    private var videoRenderer: MetalVideoRenderer?

    /// Current controller state (accumulated from multiple input events)
    private var currentControllerState = ChiakiControllerInput()

    // MARK: - Initialization

    init(host: ConsoleHost) {
        self.host = host
        self.session = ChiakiSessionWrapper()
        self.statistics = StreamStatistics()
        self.videoDecoderBridge = VideoDecoderBridge()
        self.audioPlayerBridge = AudioPlayerBridge()

        setupSession()
        Logger.session.info("StreamingViewModel initialized for \(host.nickname)")
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
    }

    // MARK: - Connection

    /// Connect to the PlayStation host
    func connect(settings: StreamSettings) {
        guard !state.isActive else {
            Logger.session.warning("Cannot connect: already active")
            return
        }

        state = .connecting
        Logger.session.info("Connecting to \(host.nickname) at \(host.address)")

        // Verify host has registration data
        guard host.registKey != 0 else {
            state = .error("Host not registered")
            Logger.session.error("Connection failed: host not registered")
            return
        }

        // Create host configuration
        let registKeyData = withUnsafeBytes(of: host.registKey.bigEndian) { Data($0) }
        let morningData = host.rpKey ?? Data(repeating: 0, count: 16)

        let hostConfig = HostConfig(
            address: host.address,
            registKey: registKeyData,
            morning: morningData,
            isPS5: host.isPS5,
            nickname: host.nickname
        )

        // Configure video based on resolution setting
        let videoCodec: ChiakiVideoCodec = settings.codec == .h265 ? .h265 : .h264
        
        videoDecoderBridge.configure(
            codec: videoCodec,
            width: Int32(settings.resolution.width),
            height: Int32(settings.resolution.height)
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
            let chiakiButton = mapButton(button)
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

    /// Map VirtualControllerButton to ChiakiControllerButtons
    private func mapButton(_ button: VirtualControllerButton) -> ChiakiControllerButtons {
        switch button {
        case .cross: return .cross
        case .circle: return .moon
        case .square: return .box
        case .triangle: return .pyramid
        case .up: return .dpadUp
        case .down: return .dpadDown
        case .left: return .dpadLeft
        case .right: return .dpadRight
        case .l1: return .l1
        case .l2: return .l2
        case .r1: return .r1
        case .r2: return .r2
        case .share: return .share
        case .options: return .options
        case .ps: return .ps
        }
    }

    // MARK: - UI Actions

    /// Toggle overlay visibility
    func toggleOverlay() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isOverlayVisible.toggle()
        }
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
            Task { @MainActor in
                self?.updateStats()
            }
        }
    }

    private func updateStats() {
        currentFrameRate = statistics.currentFrameRate
        latency = statistics.networkLatency
        bitrate = statistics.measuredBitrate
        connectionQuality = statistics.connectionQuality

        // Update resolution string based on video size
        // This would come from the video decoder config
        currentResolution = "1080p"
    }
}
