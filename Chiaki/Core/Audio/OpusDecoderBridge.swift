// SPDX-License-Identifier: AGPL-3.0-only
//
// OpusDecoderBridge.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Bridge for libchiaki's ChiakiOpusDecoder
// Decodes Opus-compressed audio from PS4/PS5 to PCM Int16
// @requirement F-001 - 核心流媒体
// @verifies BUG-005 - 音频解码修复

import Foundation

// MARK: - Opus Decoder Bridge

/// Bridge for libchiaki's ChiakiOpusDecoder
/// Decodes Opus audio to PCM Int16 for AudioPlayer
final class OpusDecoderBridge {
    // MARK: - Types

    /// Callback for audio settings changes (channels, sample rate)
    typealias SettingsCallback = (_ channels: UInt32, _ rate: UInt32) -> Void

    /// Callback for decoded PCM frames
    /// - Parameters:
    ///   - samples: Pointer to Int16 PCM samples (interleaved stereo)
    ///   - samplesCount: Total number of samples (frames × channels)
    typealias FrameCallback = (_ samples: UnsafePointer<Int16>, _ samplesCount: Int) -> Void

    // MARK: - Properties

    private var decoder: ChiakiOpusDecoder
    private var settingsCallback: SettingsCallback?
    private var frameCallback: FrameCallback?
    private let lock = NSLock()

    // MARK: - Initialization

    /// Initialize Opus decoder bridge
    /// - Parameter log: Chiaki log instance (optional)
    init(log: UnsafeMutablePointer<ChiakiLog>?) {
        decoder = ChiakiOpusDecoder()
        chiaki_opus_decoder_init(&decoder, log)
        logInfo("OpusDecoderBridge: Initialized")
    }

    deinit {
        chiaki_opus_decoder_fini(&decoder)
        logInfo("OpusDecoderBridge: Deinitialized")
    }

    // MARK: - Configuration

    /// Set callbacks for decoded audio
    /// - Parameters:
    ///   - settings: Called when audio format changes (channels, sample rate)
    ///   - frame: Called for each decoded PCM frame
    func setCallbacks(settings: @escaping SettingsCallback, frame: @escaping FrameCallback) {
        lock.lock()
        defer { lock.unlock() }

        self.settingsCallback = settings
        self.frameCallback = frame

        // Set C callbacks with self as user data
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        chiaki_opus_decoder_set_cb(
            &decoder,
            opusSettingsCallback,
            opusFrameCallback,
            selfPointer
        )

        logInfo("OpusDecoderBridge: Callbacks configured")
    }

    /// Get the audio sink for use with chiaki_session_set_audio_sink
    /// - Returns: ChiakiAudioSink configured to use this decoder
    func getAudioSink() -> ChiakiAudioSink {
        var sink = ChiakiAudioSink()
        chiaki_opus_decoder_get_sink(&decoder, &sink)
        return sink
    }

    // MARK: - Internal Callbacks

    fileprivate func handleSettings(channels: UInt32, rate: UInt32) {
        lock.lock()
        let callback = settingsCallback
        lock.unlock()

        logInfo("OpusDecoderBridge: Audio settings - \(channels) channels, \(rate) Hz")
        callback?(channels, rate)
    }

    fileprivate func handleFrame(samples: UnsafeMutablePointer<Int16>, samplesCount: Int) {
        lock.lock()
        let callback = frameCallback
        lock.unlock()

        callback?(samples, samplesCount)
    }
}

// MARK: - C Callbacks

/// C callback for audio settings changes
private let opusSettingsCallback: ChiakiOpusDecoderSettingsCallback = { channels, rate, userData in
    guard let userData = userData else { return }
    let bridge = Unmanaged<OpusDecoderBridge>.fromOpaque(userData).takeUnretainedValue()
    bridge.handleSettings(channels: channels, rate: rate)
}

/// C callback for decoded PCM frames
private let opusFrameCallback: ChiakiOpusDecoderFrameCallback = { buf, samplesCount, userData in
    guard let buf = buf, let userData = userData else { return }
    let bridge = Unmanaged<OpusDecoderBridge>.fromOpaque(userData).takeUnretainedValue()
    bridge.handleFrame(samples: buf, samplesCount: samplesCount)
}
