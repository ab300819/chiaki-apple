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

    /**
     * Volume OSD visibility state
     * @requirement F-022 - 手柄操控 UI/UX 优化
     * @satisfies AC-066 - 流媒体中音量快捷调节
     */
    var isVolumeOSDVisible: Bool = false

    /**
     * Last focused control in the streaming control menu
     * @requirement F-020 - 手柄操作友好化
     * @satisfies AC-060 - 焦点恢复逻辑
     */
    var lastControlMenuFocus: StreamingControlFocus?

    // Microphone controls
    var isMicEnabled: Bool = false
    var isMicMuted: Bool = true

    /// Called when connection is established
    var onConnected: (() -> Void)?

    let pipManager = PiPManager()
    let statsManager: StreamStatsManager
    private let inputMapper = ControllerInputMapper()

    /**
     * Controller shortcut detector for volume and other shortcuts
     * @requirement F-022 - 手柄操控 UI/UX 优化
     * @satisfies AC-066 - 流媒体中音量快捷调节
     */
    private let shortcutDetector = ControllerShortcutDetector()
    private var volumeOSDHideTask: Task<Void, Never>?

    // MARK: - Internal state

    let host: ConsoleHost
    private let session: ChiakiSessionWrapper
    private let statistics: StreamStatistics
    private let videoDecoderBridge: VideoDecoderBridge
    private let audioPlayerBridge: AudioPlayerBridge
    private let pinManager: PinManaging

    private var statsUpdateTimer: Timer?
    /// Timer for periodic controller state feedback
    /// PS5 expects regular controller updates to know the client is alive
    /// @satisfies BUG-006 - 唤醒主机后首次连接失败
    private var feedbackTimer: Timer?
    private var videoRenderer: VideoRenderer?

    /// Current controller state (accumulated from multiple input events)
    private var currentControllerState = ChiakiControllerInput()
    private var lastSettings: StreamSettings?
    private var lastIsRemote: Bool = false

    /// Connection retry state for handling PS5 startup race condition
    /// @satisfies BUG-011 - PS5 刚启动时首次连接失败
    private var connectionRetryCount: Int = 0
    private static let maxConnectionRetries = 3
    private static let connectionRetryDelay: UInt64 = 2_000_000_000 // 2 seconds

    // MARK: - PIN Management
    /// @requirement F-027 - UI 层 MVVM 合规重构
    /// @satisfies AC-092 - StreamingView Singleton 解耦

    /// Check if PIN entry is required for the host
    var requiresPinEntry: Bool {
        pinManager.requiresPinEntry(for: host)
    }

    // MARK: - Initialization

    /// Initialize with host and optional dependencies
    /// - Parameters:
    ///   - host: Console host to connect to
    ///   - pinManager: PIN manager (defaults to shared instance)
    init(host: ConsoleHost, pinManager: PinManaging? = nil) {
        self.host = host
        self.pinManager = pinManager ?? ConsolePinManager.shared
        self.session = ChiakiSessionWrapper()
        self.statistics = StreamStatistics()
        self.videoDecoderBridge = VideoDecoderBridge()
        self.audioPlayerBridge = AudioPlayerBridge()
        self.statsManager = StreamStatsManager(statistics: statistics, session: session)

        setupSession()
        setupNetworkMonitoring()
        setupVolumeShortcuts()
        setupControllerInput()
        Logger.session.info("StreamingViewModel initialized for \(host.nickname)")
    }
    
    private func setupNetworkMonitoring() {
        // Observe network changes for auto-reconnect
        _ = withObservationTracking {
            NetworkMonitor.shared.isConnected
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
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

    /**
     * Setup volume shortcut handlers
     * @requirement F-022 - 手柄操控 UI/UX 优化
     * @satisfies AC-066 - 流媒体中音量快捷调节
     */
    private func setupVolumeShortcuts() {
        shortcutDetector.onVolumeUp = { [weak self] in
            self?.adjustVolume(direction: .up)
        }
        shortcutDetector.onVolumeDown = { [weak self] in
            self?.adjustVolume(direction: .down)
        }
    }

    /**
     * Adjust volume by shortcut and show OSD
     * @requirement F-022 - 手柄操控 UI/UX 优化
     * @satisfies AC-066 - 流媒体中音量快捷调节
     */
    private func adjustVolume(direction: VolumeDirection) {
        let newVolume = VolumeAdjuster.adjustVolume(volume, direction: direction)
        setVolume(newVolume)
        showVolumeOSD()
        Logger.controller.debug("Volume adjusted via shortcut: \(newVolume)")
    }

    /**
     * Show volume OSD with auto-hide
     * @requirement F-022 - 手柄操控 UI/UX 优化
     * @satisfies AC-066 - OSD 2秒后自动隐藏
     * @satisfies AC-075 - 滑动快捷调节
     */
    func showVolumeOSD() {
        // Cancel any existing hide task
        volumeOSDHideTask?.cancel()

        // Show OSD
        withAnimation(.snappy) {
            isVolumeOSDVisible = true
        }

        // Schedule auto-hide
        volumeOSDHideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(VolumeOSD.autoHideDelay))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.snappy) {
                    self?.isVolumeOSDVisible = false
                }
            }
        }
    }

    // MARK: - Controller Input Setup

    /// Connect physical controller input to streaming session
    /// @requirement F-004 - 控制器支持
    /// @satisfies BUG-012 - 物理手柄输入未接入串流管线
    private func setupControllerInput() {
        ControllerOrchestrator.shared.onInputChanged = { [weak self] input in
            self?.sendControllerInput(input)
        }
        Logger.controller.info("Physical controller input connected to streaming session")
    }

    /// Disconnect physical controller input from streaming session
    private func teardownControllerInput() {
        ControllerOrchestrator.shared.onInputChanged = nil
        Logger.controller.info("Physical controller input disconnected from streaming session")
    }

    // MARK: - Setup

    private func setupSession() {
        // Configure bridges
        session.setVideoDecoderBridge(videoDecoderBridge)
        session.setAudioPlayerBridge(audioPlayerBridge)
        session.setStreamStatistics(statistics)

        // [satisfies] AC-085
        videoDecoderBridge.onDecodeTimeRecorded = { [weak self] durationMs in
            Task { @MainActor [weak self] in
                self?.statsManager.recordDecodeTime(durationMs)
            }
        }

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
    func setVideoRenderer(_ renderer: VideoRenderer) {
        self.videoRenderer = renderer
        videoDecoderBridge.setRenderer(renderer)

        renderer.onFrameSubmitted = { [weak self] pixelBuffer in
            self?.pipManager.enqueue(pixelBuffer)
        }

        // [satisfies] AC-085
        renderer.onRenderTimeRecorded = { [weak self] durationMs in
            Task { @MainActor [weak self] in
                self?.statsManager.recordRenderTime(durationMs)
            }
        }

        // [satisfies] AC-166 — wire renderer for diagnostics pull
        statsManager.videoRenderer = renderer
    }

    func createRenderer(renderBackend: StreamSettings.RenderBackend) -> VideoRenderer? {
        createRenderer(
            renderBackend: renderBackend,
            placeboFactory: { PlaceboVideoRenderer() },
            metalFactory: { MetalVideoRenderer() }
        )
    }

    func createRenderer(
        renderBackend: StreamSettings.RenderBackend,
        placeboFactory: @MainActor () -> VideoRenderer?,
        metalFactory: @MainActor () -> VideoRenderer?
    ) -> VideoRenderer? {
        Logger.video.info("Requested render backend: \(renderBackend.rawValue)")
        switch renderBackend {
        case .metalNative:
            guard let renderer = metalFactory() else {
                Logger.video.error("Metal Native renderer initialization failed")
                return nil
            }
            Logger.video.info("Using Metal Native renderer")
            return renderer
        case .libplacebo:
            if let ctx = PlaceboContext() {
                let preLog = ctx.createLog() != nil
                let preVk = ctx.createVulkanDevice() != nil
                let preRenderer = ctx.createRenderer() != nil
                Logger.video.info(
                    "libplacebo preflight: available=\(ctx.isAvailable), renderingReady=\(ctx.isRenderingReady), " +
                    "log=\(preLog), vulkan=\(preVk), renderer=\(preRenderer)"
                )
            } else {
                Logger.video.warning("libplacebo preflight: failed to create context")
            }
            if let renderer = placeboFactory() {
                Logger.video.info("Using libplacebo renderer")
                return renderer
            }
            Logger.video.warning("libplacebo init failed, falling back to Metal Native")
            guard let fallback = metalFactory() else {
                Logger.video.error("Metal Native fallback initialization failed")
                return nil
            }
            return fallback
        }
    }

    // MARK: - Connection

    /// Connect to the PlayStation host
    /// If host is in standby, will attempt to wake it first
    /// @satisfies BUG-011 - PS5 刚启动时首次连接失败
    func connect(settings: StreamSettings, isRemote: Bool = false) {
        lastSettings = settings
        lastIsRemote = isRemote
        connectionRetryCount = 0

        guard !state.isActive || state == .reconnecting else {
            Logger.session.warning("Cannot connect: already active")
            return
        }

        // Verify host has registration data
        guard !host.registKey.isEmpty else {
            state = .error("Host not registered")
            Logger.session.error("Connection failed: host not registered")
            return
        }

        // Check if host needs to be woken up first
        if host.state == .standby {
            state = .connecting
            Logger.session.info("Host \(host.nickname) is in standby, sending wake-up signal")

            Task {
                await wakeAndConnect(settings: settings, isRemote: isRemote)
            }
            return
        }

        // Host is online or unknown state, proceed with connection
        performConnection(settings: settings, isRemote: isRemote)
    }

    /// Wake up host and then connect
    /// @satisfies BUG-004 - 唤醒后首次连接失败修复
    private func wakeAndConnect(settings: StreamSettings, isRemote: Bool) async {
        // Track if we started discovery (so we can stop it later if needed)
        let wasDiscovering = HostManager.shared.isDiscovering

        do {
            // Ensure discovery service is running to detect host state changes
            // This is critical: without discovery, host state won't update after wake-up
            if !wasDiscovering {
                Logger.session.info("Starting discovery service for wake-up detection")
                HostManager.shared.startDiscovery()
                // Give discovery a moment to initialize
                try await Task.sleep(nanoseconds: 200_000_000) // 200ms
            }

            // Send wake-up signal
            try await HostManager.shared.wakeUp(host)
            Logger.session.info("Wake-up signal sent to \(host.nickname), waiting for host to come online")

            // Wait for host to wake up (poll every 1 second, timeout after 30 seconds)
            let maxAttempts = 30
            var attempts = 0

            while attempts < maxAttempts {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                attempts += 1

                // Check if host is now online via HostManager
                if let updatedHost = HostManager.shared.host(byId: host.id),
                   updatedHost.state == .online {
                    Logger.session.info("Host \(host.nickname) is now online after \(attempts) seconds")
                    performConnection(settings: settings, isRemote: isRemote)
                    return
                }

                // Update UI with progress
                if attempts % 5 == 0 {
                    Logger.session.debug("Waiting for host to wake up... (\(attempts)/\(maxAttempts)s)")
                }
            }

            // Timeout - host didn't wake up in time
            state = .error(String(localized: "streaming.wakeUpTimeout"))
            Logger.session.error("Wake-up timeout: host did not come online within \(maxAttempts) seconds")

        } catch {
            state = .error(error.localizedDescription)
            Logger.session.error("Failed to wake up host: \(error)")
        }
    }

    /// Perform the actual connection (after wake-up if needed)
    private func performConnection(settings: StreamSettings, isRemote: Bool) {
        state = .connecting
        Logger.session.info("Connecting to \(host.nickname) at \(host.address)")

        let hostConfig = HostConfig(
            address: host.address,
            registKey: host.registKey,
            morning: host.rpKey,
            isPS5: host.isPS5,
            nickname: host.nickname
        )

        let profile = isRemote ? settings.remoteProfile : settings.localProfile

        // Configure video codec based on settings
        // HDR requires H.265 codec; use H.265 HDR when hdrEnabled is true
        let videoCodec: ChiakiVideoCodec
        if settings.hdrEnabled && settings.codec == .h265 {
            videoCodec = .h265HDR
            Logger.session.info("HDR enabled with H.265, using H.265 HDR codec")
        } else if settings.codec == .h265 {
            videoCodec = .h265
            Logger.session.info("Using H.265 codec (HDR disabled: \(settings.hdrEnabled))")
        } else {
            videoCodec = .h264
            Logger.session.info("Using H.264 codec")
        }
        Logger.session.info("Stream settings - hdrEnabled: \(settings.hdrEnabled), codec: \(settings.codec.rawValue), selected: \(videoCodec.displayName)")

        videoDecoderBridge.configure(
            codec: videoCodec,
            width: Int32(profile.resolution.width),
            height: Int32(profile.resolution.height),
            fps: profile.frameRate.rawValue
        )

        // Configure session stream settings (including HDR codec for isHDR property)
        let chiakiResolution: ChiakiResolution = switch profile.resolution {
        case .r540p: .r540p
        case .r720p: .r720p
        case .r1080p: .r1080p
        case .r2160p: .r1080p  // Fallback to 1080p for 4K (not supported by ChiakiResolution)
        }
        let chiakiFPS: ChiakiFPS = profile.frameRate == .fps60 ? .fps60 : .fps30
        let streamConfig = StreamConfig(
            resolution: chiakiResolution,
            fps: chiakiFPS,
            codec: videoCodec,
            bitrate: UInt32(profile.bitrate * 1000),  // Convert kbps to bps
            autoDowngrade: true
        )
        session.configure(stream: streamConfig)

        // Start connection
        // @satisfies BUG-011 - PS5 刚启动时首次连接失败
        do {
            try session.connect(to: hostConfig)
            startStatsUpdate()
        } catch {
            Logger.session.error("Connection failed: \(error)")
            retryOrFail(error: error.localizedDescription, settings: settings, isRemote: isRemote)
        }
    }

    /// Retry connection or set error state if max retries exceeded
    /// @satisfies BUG-011 - PS5 刚启动时首次连接失败
    private func retryOrFail(error: String, settings: StreamSettings, isRemote: Bool) {
        connectionRetryCount += 1

        if connectionRetryCount <= Self.maxConnectionRetries {
            Logger.session.warning("Connection failed (attempt \(connectionRetryCount)/\(Self.maxConnectionRetries)), retrying in 2s...")
            state = .connecting
            Task {
                try? await Task.sleep(nanoseconds: Self.connectionRetryDelay)
                guard state == .connecting else { return }  // User may have cancelled
                performConnection(settings: settings, isRemote: isRemote)
            }
        } else {
            Logger.session.error("Connection failed after \(Self.maxConnectionRetries) retries: \(error)")
            state = .error(error)
        }
    }

    /// Disconnect from the host
    func disconnect() {
        stopFeedbackTimer()
        statsUpdateTimer?.invalidate()
        statsUpdateTimer = nil
        teardownControllerInput()

        session.disconnect()
        state = .disconnected

        Logger.session.info("Disconnected from \(host.nickname)")
    }

    // MARK: - Input

    /**
     * Send controller input to the session
     * Also passes button state to shortcut detector for volume shortcuts
     * @requirement F-022 - 手柄操控 UI/UX 优化
     * @satisfies AC-066 - 流媒体中音量快捷调节
     */
    func sendControllerInput(_ input: ChiakiControllerInput) {
        guard state == .streaming else { return }

        // Sync to currentControllerState so feedbackTimer sends the latest input
        // Without this, the 8ms feedback timer overwrites physical controller input with stale zeros
        currentControllerState = input

        // Check for volume shortcuts
        shortcutDetector.updateButtons(input.buttons)

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
    /// @satisfies AC-159, AC-161, AC-163
    func setVideoPreset(_ preset: StreamSettings.VideoPreset) {
        videoPreset = preset
        videoRenderer?.setFilterConfig(preset.filterConfig)
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
        videoRenderer?.vrrEnabled = settings.vrrEnabled
        videoRenderer?.setFilterConfig(settings.videoPreset.filterConfig)

        let profile = lastIsRemote ? settings.remoteProfile : settings.localProfile
        videoRenderer?.updateRenderingPolicy(fps: profile.frameRate.rawValue)
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

    /// @satisfies BUG-011 - PS5 刚启动时首次连接失败
    private func handleSessionStateChange(_ sessionState: SessionState) {
        switch sessionState {
        case .idle:
            stopFeedbackTimer()
            state = .disconnected
        case .connecting:
            state = .connecting
        case .connected:
            state = .connected
        case .streaming:
            state = .streaming
            connectionRetryCount = 0  // Reset retry count on successful connection
            startFeedbackTimer()  // Start periodic feedback to keep connection alive
            onConnected?()
        case .disconnecting:
            stopFeedbackTimer()
            state = .disconnected
        case .error(let error):
            stopFeedbackTimer()
            // Try to retry if we haven't exceeded max retries
            if let settings = lastSettings {
                retryOrFail(error: error.description, settings: settings, isRemote: lastIsRemote)
            } else {
                state = .error(error.description)
            }
        }
    }

    private func handleLoginPinRequest(pinIncorrect: Bool) {
        // TODO: Show PIN entry UI
        Logger.session.info("Login PIN requested (incorrect: \(pinIncorrect))")
    }

    /// Forward rumble feedback to physical controller
    /// @satisfies BUG-012 - 物理手柄输入未接入串流管线
    private func handleRumble(left: UInt8, right: UInt8) {
        ControllerOrchestrator.shared.applyRumble(left: left, right: right)
    }

    // MARK: - Statistics Update

    private func startStatsUpdate() {
        // Immediately update stats (including HDR status from session config)
        statsManager.update()

        statsUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.statsManager.update()
            }
        }
    }

    // MARK: - Controller Feedback Timer

    /// Start periodic controller feedback to keep PS5 connection alive
    /// PS5 expects regular controller state updates; without them it disconnects
    /// Qt client sends updates every 4ms (SETSU_UPDATE_INTERVAL_MS)
    /// We use 8ms (125 Hz) as a reasonable balance between responsiveness and overhead
    /// @satisfies BUG-006 - 唤醒主机后首次连接失败
    private func startFeedbackTimer() {
        // Only start when streaming
        guard state == .streaming else { return }

        // Cancel existing timer if any
        feedbackTimer?.invalidate()

        // Send feedback every 8ms (125 Hz)
        // This is slightly less aggressive than Qt's 4ms but still keeps connection alive
        feedbackTimer = Timer.scheduledTimer(withTimeInterval: 0.008, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Send current controller state even if unchanged
                // This acts as a heartbeat to keep the PS5 connection alive
                self.session.sendControllerState(self.currentControllerState)
            }
        }

        // Ensure timer runs even during UI interactions
        if let timer = feedbackTimer {
            RunLoop.main.add(timer, forMode: .common)
        }

        Logger.session.info("Controller feedback timer started (8ms interval)")
    }

    /// Stop the feedback timer
    private func stopFeedbackTimer() {
        feedbackTimer?.invalidate()
        feedbackTimer = nil
        Logger.session.debug("Controller feedback timer stopped")
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
