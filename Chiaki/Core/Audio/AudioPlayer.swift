// SPDX-License-Identifier: AGPL-3.0-only
//
// AudioPlayer.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Low-latency audio player using AVAudioEngine with pull-mode rendering
// Design based on chiaki-ng/android audio-output.cpp Oboe callback model

import Foundation
import AVFoundation
import Accelerate

// MARK: - Audio Player Error

enum AudioPlayerError: Error, CustomStringConvertible {
    case formatCreationFailed
    case engineStartFailed(Error)
    case audioSessionSetupFailed(Error)

    var description: String {
        switch self {
        case .formatCreationFailed:
            return "Failed to create audio format"
        case .engineStartFailed(let error):
            return "Failed to start audio engine: \(error.localizedDescription)"
        case .audioSessionSetupFailed(let error):
            return "Failed to setup audio session: \(error.localizedDescription)"
        }
    }
}

// MARK: - Audio Player

/// Low-latency audio player using AVAudioEngine with lock-free circular buffer
/// Uses AVAudioSourceNode for pull-mode rendering (similar to Android Oboe callback)
final class AudioPlayer {
    // MARK: - Properties

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let format: AVAudioFormat

    /// Lock-free circular buffer (32 chunks × 512 samples = ~340ms buffer at 48kHz stereo)
    private let circularBuffer: CircularAudioBuffer<Float>

    private var isPlaying = false
    private let playbackLock = NSLock()

    // Configuration
    private let sampleRate: Double
    private let channelCount: AVAudioChannelCount

    // Statistics
    private(set) var underrunCount: UInt64 = 0
    private(set) var samplesReceived: UInt64 = 0
    private(set) var samplesPlayed: UInt64 = 0

    // Volume control
    private var volume: Float = 1.0

    // MARK: - Initialization

    /// Initialize audio player
    /// - Parameters:
    ///   - sampleRate: Audio sample rate (default 48000 Hz, PS4/PS5 standard)
    ///   - channelCount: Number of channels (default 2 for stereo)
    ///   - bufferChunks: Number of buffer chunks (default 32)
    ///   - chunkSize: Samples per chunk (default 512)
    init(
        sampleRate: Double = 48000,
        channelCount: AVAudioChannelCount = 2,
        bufferChunks: Int = 32,
        chunkSize: Int = 512
    ) throws {
        self.sampleRate = sampleRate
        self.channelCount = channelCount

        // Create audio format
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: channelCount
        ) else {
            throw AudioPlayerError.formatCreationFailed
        }
        self.format = format

        // Create circular buffer (stores interleaved samples)
        // Total buffer: chunkSize * bufferChunks * channelCount samples
        self.circularBuffer = CircularAudioBuffer<Float>(
            chunkCount: bufferChunks,
            chunkSize: chunkSize * Int(channelCount)
        )

        // Setup audio session (iOS/tvOS only)
        try setupAudioSession()

        // Setup audio engine
        setupEngine()

        logInfo("AudioPlayer: Initialized at \(Int(sampleRate))Hz, \(channelCount) channels")
    }

    deinit {
        stop()
        logInfo("AudioPlayer: Deinitialized")
    }

    // MARK: - Public Methods

    /// Start audio playback
    func start() throws {
        playbackLock.lock()
        defer { playbackLock.unlock() }

        guard !isPlaying else { return }

        do {
            try engine.start()
            isPlaying = true
            logInfo("AudioPlayer: Started")
        } catch {
            throw AudioPlayerError.engineStartFailed(error)
        }
    }

    /// Stop audio playback
    func stop() {
        playbackLock.lock()
        defer { playbackLock.unlock() }

        guard isPlaying else { return }

        engine.stop()
        circularBuffer.reset()
        isPlaying = false
        logInfo("AudioPlayer: Stopped")
    }

    /// Pause audio playback
    func pause() {
        playbackLock.lock()
        defer { playbackLock.unlock() }

        guard isPlaying else { return }

        engine.pause()
        isPlaying = false
        logInfo("AudioPlayer: Paused")
    }

    /// Resume audio playback
    func resume() throws {
        playbackLock.lock()
        defer { playbackLock.unlock() }

        guard !isPlaying else { return }

        do {
            try engine.start()
            isPlaying = true
            logInfo("AudioPlayer: Resumed")
        } catch {
            throw AudioPlayerError.engineStartFailed(error)
        }
    }

    /// Receive audio data from libchiaki (Int16 PCM)
    /// - Parameters:
    ///   - samples: Pointer to Int16 PCM samples (interleaved)
    ///   - frameCount: Number of frames (each frame has channelCount samples)
    func receiveAudio(samples: UnsafePointer<Int16>, frameCount: Int) {
        let sampleCount = frameCount * Int(channelCount)

        // Allocate temporary buffer for Float conversion
        let floatSamples = UnsafeMutablePointer<Float>.allocate(capacity: sampleCount)
        defer { floatSamples.deallocate() }

        // Convert Int16 to Float32 using vDSP for SIMD acceleration
        // Int16 range [-32768, 32767] -> Float range [-1.0, 1.0]
        vDSP_vflt16(samples, 1, floatSamples, 1, vDSP_Length(sampleCount))
        var scale: Float = 1.0 / 32768.0
        vDSP_vsmul(floatSamples, 1, &scale, floatSamples, 1, vDSP_Length(sampleCount))

        // Push to circular buffer
        let pushed = circularBuffer.push(floatSamples, count: sampleCount)
        samplesReceived += UInt64(pushed)
    }

    /// Receive audio data (Float32 PCM)
    /// - Parameters:
    ///   - samples: Pointer to Float32 PCM samples (interleaved)
    ///   - sampleCount: Number of samples (frames × channels)
    func receiveAudioFloat(samples: UnsafePointer<Float>, sampleCount: Int) {
        let pushed = circularBuffer.push(samples, count: sampleCount)
        samplesReceived += UInt64(pushed)
    }

    /// Set playback volume
    /// - Parameter volume: Volume level (0.0 - 1.0)
    func setVolume(_ volume: Float) {
        self.volume = max(0.0, min(1.0, volume))
        engine.mainMixerNode.outputVolume = self.volume
    }

    /// Reset statistics
    func resetStatistics() {
        underrunCount = 0
        samplesReceived = 0
        samplesPlayed = 0
        circularBuffer.resetStatistics()
    }

    /// Flush audio buffer
    func flush() {
        circularBuffer.reset()
    }

    // MARK: - Status

    /// Whether audio is currently playing
    var playing: Bool { isPlaying }

    /// Current buffer fill ratio (0.0 - 1.0)
    var bufferFillRatio: Double { circularBuffer.fillRatio }

    /// Buffer overrun count (data dropped due to full buffer)
    var bufferOverrunCount: UInt64 { circularBuffer.overrunCount }

    // MARK: - Private Methods

    private func setupAudioSession() throws {
        #if os(iOS) || os(tvOS)
        let session = AVAudioSession.sharedInstance()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: session
        )

        do {
            // Set category for game audio playback
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )

            // Request low latency buffer duration (5ms target)
            try session.setPreferredIOBufferDuration(0.005)

            // Activate session
            try session.setActive(true)

            logInfo("AudioPlayer: Audio session configured (buffer: \(session.ioBufferDuration * 1000)ms)")
        } catch {
            throw AudioPlayerError.audioSessionSetupFailed(error)
        }
        #endif
    }

    @objc private func handleInterruption(notification: Notification) {
        #if os(iOS) || os(tvOS)
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            logInfo("AudioPlayer: Interruption began")
            pause()
        case .ended:
            logInfo("AudioPlayer: Interruption ended")
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                do {
                    try resume()
                } catch {
                    logError("AudioPlayer: Failed to resume after interruption: \(error.localizedDescription)")
                }
            }
        @unknown default:
            break
        }
        #endif
    }

    private func setupEngine() {
        // Create source node with pull-mode rendering callback
        // This is similar to Android Oboe's audio callback model
        sourceNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            return self.renderCallback(frameCount: frameCount, audioBufferList: audioBufferList)
        }

        guard let sourceNode = sourceNode else {
            logError("AudioPlayer: Failed to create source node")
            return
        }

        // Attach and connect nodes
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)

        // Set initial volume
        engine.mainMixerNode.outputVolume = volume

        // Prepare engine
        engine.prepare()

        logInfo("AudioPlayer: Engine configured")
    }

    /// Audio render callback (runs on real-time audio thread)
    private func renderCallback(frameCount: UInt32, audioBufferList: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let requestedSamples = Int(frameCount) * Int(channelCount)

        // Allocate temporary buffer for interleaved data
        let tempBuffer = UnsafeMutablePointer<Float>.allocate(capacity: requestedSamples)
        defer { tempBuffer.deallocate() }

        // Read from circular buffer
        let poppedSamples = circularBuffer.pop(tempBuffer, count: requestedSamples)
        samplesPlayed += UInt64(poppedSamples)

        // Fill with silence if not enough data (underrun)
        if poppedSamples < requestedSamples {
            memset(
                tempBuffer.advanced(by: poppedSamples),
                0,
                (requestedSamples - poppedSamples) * MemoryLayout<Float>.size
            )
            underrunCount += 1
            if underrunCount % 100 == 0 {
                logWarning("AudioPlayer: Buffer underrun count: \(underrunCount)")
            }
        }

        // De-interleave to separate channel buffers
        // Input: [L0, R0, L1, R1, L2, R2, ...]
        // Output: Buffer0 [L0, L1, L2, ...], Buffer1 [R0, R1, R2, ...]
        for channel in 0..<Int(channelCount) {
            guard channel < ablPointer.count,
                  let channelData = ablPointer[channel].mData?.assumingMemoryBound(to: Float.self) else {
                continue
            }

            // Extract samples for this channel
            for frame in 0..<Int(frameCount) {
                let sourceIndex = frame * Int(channelCount) + channel
                channelData[frame] = tempBuffer[sourceIndex]
            }
        }

        return noErr
    }
}

// MARK: - Audio Player Bridge

/// Bridge for connecting libchiaki audio callbacks to AudioPlayer
final class AudioPlayerBridge {
    // MARK: - Properties

    private var player: AudioPlayer?
    private let initLock = NSLock()

    /// Audio configuration
    private(set) var sampleRate: Double = 48000
    private(set) var channelCount: AVAudioChannelCount = 2

    // MARK: - Initialization

    init() {
        logInfo("AudioPlayerBridge: Created")
    }

    deinit {
        shutdown()
        logInfo("AudioPlayerBridge: Deinitialized")
    }

    // MARK: - Public Methods

    /// Configure audio parameters (call before streaming starts)
    func configure(sampleRate: Double, channelCount: UInt32) {
        initLock.lock()
        defer { initLock.unlock() }

        self.sampleRate = sampleRate
        self.channelCount = AVAudioChannelCount(channelCount)

        logInfo("AudioPlayerBridge: Configured for \(Int(sampleRate))Hz, \(channelCount) channels")
    }

    /// Initialize and start audio player
    func start() throws {
        initLock.lock()
        defer { initLock.unlock() }

        guard player == nil else { return }

        player = try AudioPlayer(
            sampleRate: sampleRate,
            channelCount: channelCount
        )
        try player?.start()

        logInfo("AudioPlayerBridge: Player started")
    }

    /// Receive audio samples from libchiaki
    func receiveAudio(samples: UnsafePointer<Int16>, frameCount: Int) {
        player?.receiveAudio(samples: samples, frameCount: frameCount)
    }

    /// Receive audio samples (Float32)
    func receiveAudioFloat(samples: UnsafePointer<Float>, sampleCount: Int) {
        player?.receiveAudioFloat(samples: samples, sampleCount: sampleCount)
    }

    /// Set volume
    func setVolume(_ volume: Float) {
        player?.setVolume(volume)
    }

    /// Get underrun count
    var underrunCount: UInt64 {
        player?.underrunCount ?? 0
    }

    /// Get buffer fill ratio
    var bufferFillRatio: Double {
        player?.bufferFillRatio ?? 0
    }

    /// Shutdown audio player
    func shutdown() {
        initLock.lock()
        defer { initLock.unlock() }

        player?.stop()
        player = nil

        logInfo("AudioPlayerBridge: Shutdown complete")
    }
}
