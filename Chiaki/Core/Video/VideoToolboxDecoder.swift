// SPDX-License-Identifier: AGPL-3.0-only
//
// VideoToolboxDecoder.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Hardware-accelerated video decoder using VideoToolbox
// Design based on chiaki-ng/android video-decoder.c dual-thread model
// @requirement F-001 - 核心流媒体
// @satisfies AC-054 - 核心流程日志覆盖

import Foundation
import VideoToolbox
import CoreVideo
import CoreMedia
import QuartzCore

// MARK: - Decoder Error

/// Video decoder errors
enum VideoDecoderError: Error, CustomStringConvertible {
    case sessionCreationFailed(OSStatus)
    case formatDescriptionFailed(OSStatus)
    case decodeFailed(OSStatus)
    case invalidParameterSets
    case notInitialized

    var description: String {
        switch self {
        case .sessionCreationFailed(let status):
            return "Failed to create decompression session: \(status)"
        case .formatDescriptionFailed(let status):
            return "Failed to create format description: \(status)"
        case .decodeFailed(let status):
            return "Failed to decode frame: \(status)"
        case .invalidParameterSets:
            return "Invalid parameter sets (SPS/PPS/VPS)"
        case .notInitialized:
            return "Decoder not initialized"
        }
    }
}

// MARK: - VideoToolbox Decoder

/// Hardware-accelerated video decoder using VideoToolbox
/// Supports H.264 and H.265 (HEVC) codecs with async decoding and frame reordering
final class VideoToolboxDecoder {
    // MARK: - Properties

    private var decompressionSession: VTDecompressionSession?
    private var formatDescription: CMVideoFormatDescription?

    private let outputQueue = DispatchQueue(label: "chiaki.video.output", qos: .userInteractive)
    private let decodeLock = NSLock()

    /// Decoded frame output callback
    var onFrameDecoded: ((CVPixelBuffer, CMTime) -> Void)?

    /// Decode time callback (ms)
    /// [satisfies] AC-085
    var onDecodeTimeRecorded: ((Double) -> Void)?

    /// Decode statistics
    private(set) var decodedFrameCount: UInt64 = 0
    private(set) var droppedFrameCount: UInt64 = 0

    // Decode timing tracking (timestamp -> startTime)
    private var decodeStartTimes: [UInt64: CFTimeInterval] = [:]
    private let timingLock = NSLock()

    // Frame reorder buffer (for B-frames)
    private var frameReorderBuffer: [(CVPixelBuffer, CMTime)] = []
    private let maxReorderBufferSize = 4

    // MARK: - Codec Configuration

    private let codec: ChiakiVideoCodec
    private let width: Int32
    private let height: Int32

    /// Whether the decoder is initialized
    var isInitialized: Bool {
        decodeLock.lock()
        defer { decodeLock.unlock() }
        return decompressionSession != nil
    }

    // MARK: - Initialization

    /// Initialize decoder with codec and dimensions
    /// - Parameters:
    ///   - codec: Video codec (H.264 or H.265)
    ///   - width: Video width
    ///   - height: Video height
    init(codec: ChiakiVideoCodec, width: Int32, height: Int32) {
        self.codec = codec
        self.width = width
        self.height = height

        logInfo("VideoToolboxDecoder: Created for \(codec) \(width)x\(height)")
    }

    deinit {
        shutdown()
        logInfo("VideoToolboxDecoder: Deinitialized")
    }

    // MARK: - Public Methods

    /// Initialize decoder with parameter sets (call after receiving SPS/PPS)
    /// - Parameters:
    ///   - sps: Sequence Parameter Set
    ///   - pps: Picture Parameter Set
    ///   - vps: Video Parameter Set (H.265 only, optional for H.264)
    func initialize(sps: Data, pps: Data, vps: Data? = nil) throws {
        decodeLock.lock()
        defer { decodeLock.unlock() }

        // Close existing session if any
        if let session = decompressionSession {
            VTDecompressionSessionInvalidate(session)
            decompressionSession = nil
        }

        // Create format description
        formatDescription = try createFormatDescription(sps: sps, pps: pps, vps: vps)

        // Create decompression session
        let pixelFormat = codec.isHDR ? kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        logInfo("VideoToolboxDecoder: Creating session for \(width)x\(height), codec=\(codec.displayName), isHDR=\(codec.isHDR), pixelFormat=\(pixelFormat == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange ? "P010(10-bit)" : "NV12(8-bit)")")
        
        let destinationAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]

        var callbacks = VTDecompressionOutputCallbackRecord(
            decompressionOutputCallback: decompressionOutputCallback,
            decompressionOutputRefCon: Unmanaged.passUnretained(self).toOpaque()
        )

        let status = VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: formatDescription!,
            decoderSpecification: nil,
            imageBufferAttributes: destinationAttributes as CFDictionary,
            outputCallback: &callbacks,
            decompressionSessionOut: &decompressionSession
        )

        guard status == noErr else {
            throw VideoDecoderError.sessionCreationFailed(status)
        }

        // Enable low-latency real-time decoding
        VTSessionSetProperty(
            decompressionSession!,
            key: kVTDecompressionPropertyKey_RealTime,
            value: kCFBooleanTrue
        )

        // Reset statistics
        decodedFrameCount = 0
        droppedFrameCount = 0
        frameReorderBuffer.removeAll()

        logInfo("VideoToolboxDecoder: Initialized successfully")
    }

    /// Submit video data for decoding (called from libchiaki callback)
    /// - Parameters:
    ///   - data: NAL unit data pointer
    ///   - size: Data size in bytes
    ///   - timestamp: Presentation timestamp (90kHz)
    func decodeFrame(_ data: UnsafePointer<UInt8>, size: Int, timestamp: UInt64) {
        decodeLock.lock()
        guard let session = decompressionSession, let formatDesc = formatDescription else {
            decodeLock.unlock()
            droppedFrameCount += 1
            return
        }
        decodeLock.unlock()

        // Create CMBlockBuffer
        var blockBuffer: CMBlockBuffer?
        var status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: UnsafeMutableRawPointer(mutating: data),
            blockLength: size,
            blockAllocator: kCFAllocatorNull,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: size,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        guard status == kCMBlockBufferNoErr, let buffer = blockBuffer else {
            droppedFrameCount += 1
            logWarning("VideoToolboxDecoder: Failed to create block buffer: \(status)")
            return
        }

        // Create CMSampleBuffer
        var sampleBuffer: CMSampleBuffer?
        var sampleSize = size
        status = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: buffer,
            formatDescription: formatDesc,
            sampleCount: 1,
            sampleTimingEntryCount: 0,
            sampleTimingArray: nil,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        )

        guard status == noErr, let sample = sampleBuffer else {
            droppedFrameCount += 1
            logWarning("VideoToolboxDecoder: Failed to create sample buffer: \(status)")
            return
        }

        // Async decode
        let decodeFlags: VTDecodeFrameFlags = [._EnableAsynchronousDecompression]
        var infoFlags: VTDecodeInfoFlags = []

        // [satisfies] AC-085
        timingLock.lock()
        decodeStartTimes[timestamp] = CACurrentMediaTime()
        timingLock.unlock()

        let decodeStatus = VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: sample,
            flags: decodeFlags,
            frameRefcon: UnsafeMutableRawPointer(bitPattern: UInt(timestamp)),
            infoFlagsOut: &infoFlags
        )

        if decodeStatus != noErr {
            droppedFrameCount += 1
            logWarning("VideoToolboxDecoder: Decode failed: \(decodeStatus)")
        }
    }

    /// Shutdown decoder and release resources
    func shutdown() {
        decodeLock.lock()
        defer { decodeLock.unlock() }

        if let session = decompressionSession {
            // Wait for pending frames
            VTDecompressionSessionWaitForAsynchronousFrames(session)
            VTDecompressionSessionInvalidate(session)
            decompressionSession = nil
        }
        formatDescription = nil
        frameReorderBuffer.removeAll()

        logInfo("VideoToolboxDecoder: Shutdown complete")
    }

    /// Flush pending frames from reorder buffer
    func flush() {
        outputQueue.async { [weak self] in
            guard let self = self else { return }

            // Output all buffered frames in order
            self.frameReorderBuffer.sort { $0.1 < $1.1 }
            for (buffer, time) in self.frameReorderBuffer {
                self.onFrameDecoded?(buffer, time)
            }
            self.frameReorderBuffer.removeAll()
        }
    }

    /// Reset statistics
    func resetStatistics() {
        decodeLock.lock()
        decodedFrameCount = 0
        droppedFrameCount = 0
        decodeLock.unlock()
    }

    // MARK: - Private Methods

    private func createFormatDescription(sps: Data, pps: Data, vps: Data?) throws -> CMVideoFormatDescription {
        var formatDescription: CMVideoFormatDescription?

        if codec.isH265, let vps = vps {
            // H.265/HEVC
            try sps.withUnsafeBytes { spsPtr in
                try pps.withUnsafeBytes { ppsPtr in
                    try vps.withUnsafeBytes { vpsPtr in
                        guard let spsBase = spsPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                              let ppsBase = ppsPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                              let vpsBase = vpsPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                            throw VideoDecoderError.invalidParameterSets
                        }

                        var parameterSetPointers: [UnsafePointer<UInt8>] = [vpsBase, spsBase, ppsBase]
                        var parameterSetSizes: [Int] = [vps.count, sps.count, pps.count]

                        let status = CMVideoFormatDescriptionCreateFromHEVCParameterSets(
                            allocator: kCFAllocatorDefault,
                            parameterSetCount: 3,
                            parameterSetPointers: &parameterSetPointers,
                            parameterSetSizes: &parameterSetSizes,
                            nalUnitHeaderLength: 4,
                            extensions: nil,
                            formatDescriptionOut: &formatDescription
                        )

                        guard status == noErr else {
                            throw VideoDecoderError.formatDescriptionFailed(status)
                        }
                    }
                }
            }
        } else {
            // H.264/AVC
            try sps.withUnsafeBytes { spsPtr in
                try pps.withUnsafeBytes { ppsPtr in
                    guard let spsBase = spsPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                          let ppsBase = ppsPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                        throw VideoDecoderError.invalidParameterSets
                    }

                    var parameterSetPointers: [UnsafePointer<UInt8>] = [spsBase, ppsBase]
                    var parameterSetSizes: [Int] = [sps.count, pps.count]

                    let status = CMVideoFormatDescriptionCreateFromH264ParameterSets(
                        allocator: kCFAllocatorDefault,
                        parameterSetCount: 2,
                        parameterSetPointers: &parameterSetPointers,
                        parameterSetSizes: &parameterSetSizes,
                        nalUnitHeaderLength: 4,
                        formatDescriptionOut: &formatDescription
                    )

                    guard status == noErr else {
                        throw VideoDecoderError.formatDescriptionFailed(status)
                    }
                }
            }
        }

        guard let desc = formatDescription else {
            throw VideoDecoderError.invalidParameterSets
        }

        return desc
    }

    /// Handle decoded frame output (frame reordering)
    fileprivate func handleDecodedFrame(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime, timestampValue: UInt64? = nil) {
        // [satisfies] AC-085
        if let pts = timestampValue {
            timingLock.lock()
            if let startTime = decodeStartTimes.removeValue(forKey: pts) {
                let durationMs = (CACurrentMediaTime() - startTime) * 1000.0
                onDecodeTimeRecorded?(durationMs)
            }
            timingLock.unlock()
        }

        outputQueue.async { [weak self] in
            guard let self = self else { return }

            // Add to reorder buffer
            self.frameReorderBuffer.append((pixelBuffer, presentationTime))

            // Sort by PTS
            self.frameReorderBuffer.sort { $0.1 < $1.1 }

            // Output oldest frame when buffer is full
            while self.frameReorderBuffer.count > self.maxReorderBufferSize {
                let (buffer, time) = self.frameReorderBuffer.removeFirst()
                self.decodedFrameCount += 1
                
                if self.decodedFrameCount % 100 == 0 {
                    logDebug("VideoToolboxDecoder: Decoded \(self.decodedFrameCount) frames, dropped \(self.droppedFrameCount)")
                }
                
                self.onFrameDecoded?(buffer, time)
            }
        }
    }
}

// MARK: - C Callback

private func decompressionOutputCallback(
    decompressionOutputRefCon: UnsafeMutableRawPointer?,
    sourceFrameRefCon: UnsafeMutableRawPointer?,
    status: OSStatus,
    infoFlags: VTDecodeInfoFlags,
    imageBuffer: CVImageBuffer?,
    presentationTimeStamp: CMTime,
    presentationDuration: CMTime
) {
    guard status == noErr,
          let refCon = decompressionOutputRefCon,
          let pixelBuffer = imageBuffer else {
        if status != noErr {
            logWarning("VideoToolboxDecoder: Decode callback error: \(status)")
        }
        return
    }

    let decoder = Unmanaged<VideoToolboxDecoder>.fromOpaque(refCon).takeUnretainedValue()

    // Recover timestamp from frameRefcon
    let timestamp: CMTime
    let pts: UInt64?
    if let refcon = sourceFrameRefCon {
        let ptsVal = UInt64(UInt(bitPattern: refcon))
        pts = ptsVal
        timestamp = CMTime(value: CMTimeValue(ptsVal), timescale: 90000)
    } else {
        pts = nil
        timestamp = presentationTimeStamp
    }

    decoder.handleDecodedFrame(pixelBuffer, presentationTime: timestamp, timestampValue: pts)
}

// MARK: - Video Decoder Bridge

/// Bridge for connecting libchiaki video callbacks to VideoToolbox decoder
final class VideoDecoderBridge {
    // MARK: - Properties

    private var decoder: VideoToolboxDecoder?
    private var renderer: VideoRenderer?

    private var pendingSPS: Data?
    private var pendingPPS: Data?
    private var pendingVPS: Data?

    private let initLock = NSLock()

    /// Current codec
    private(set) var codec: ChiakiVideoCodec = .h265

    /// Video dimensions
    private(set) var width: Int32 = 1920
    private(set) var height: Int32 = 1080

    /// Decode time callback
    /// [satisfies] AC-085
    var onDecodeTimeRecorded: ((Double) -> Void)?

    // MARK: - Initialization


    init() {
        logInfo("VideoDecoderBridge: Created")
    }

    deinit {
        shutdown()
        logInfo("VideoDecoderBridge: Deinitialized")
    }

    // MARK: - Public Methods

    /// Set video renderer for decoded frame output
    func setRenderer(_ renderer: VideoRenderer) {
        self.renderer = renderer
    }

    /// Configure decoder parameters (call before streaming starts)
    func configure(codec: ChiakiVideoCodec, width: Int32, height: Int32, fps: Int? = nil) {
        initLock.lock()
        defer { initLock.unlock() }

        self.codec = codec
        self.width = width
        self.height = height

        if let fps = fps {
            renderer?.updateRenderingPolicy(fps: fps)
        }

        // Reset pending parameter sets
        pendingSPS = nil
        pendingPPS = nil
        pendingVPS = nil

        logInfo("VideoDecoderBridge: Configured for \(codec) \(width)x\(height)")
    }

    /// Receive SPS (Sequence Parameter Set)
    func receiveSPS(_ data: Data) {
        initLock.lock()
        pendingSPS = data
        tryInitializeDecoder()
        initLock.unlock()
    }

    /// Receive PPS (Picture Parameter Set)
    func receivePPS(_ data: Data) {
        initLock.lock()
        pendingPPS = data
        tryInitializeDecoder()
        initLock.unlock()
    }

    /// Receive VPS (Video Parameter Set, H.265 only)
    func receiveVPS(_ data: Data) {
        initLock.lock()
        pendingVPS = data
        tryInitializeDecoder()
        initLock.unlock()
    }

    /// Receive video frame data for decoding
    /// Parses NAL units from Annex-B stream and extracts parameter sets
    func receiveFrame(_ data: UnsafePointer<UInt8>, size: Int, timestamp: UInt64) {
        initLock.lock()
        defer { initLock.unlock() }

        // Parse NAL units from Annex-B stream
        parseNALUnits(data, size: size, timestamp: timestamp)
    }

    // MARK: - NAL Unit Parsing

    /// Parse NAL units from Annex-B format stream
    /// Extracts VPS/SPS/PPS and forwards frame data to decoder
    private func parseNALUnits(_ data: UnsafePointer<UInt8>, size: Int, timestamp: UInt64) {
        var offset = 0
        var nalStart = -1
        var nalType: UInt8 = 0

        // Find NAL units by scanning for start codes (00 00 00 01 or 00 00 01)
        while offset < size {
            // Check for 3-byte or 4-byte start code
            let hasStartCode3 = offset + 2 < size &&
                data[offset] == 0x00 && data[offset + 1] == 0x00 && data[offset + 2] == 0x01
            let hasStartCode4 = offset + 3 < size &&
                data[offset] == 0x00 && data[offset + 1] == 0x00 &&
                data[offset + 2] == 0x00 && data[offset + 3] == 0x01

            if hasStartCode4 || hasStartCode3 {
                // Process previous NAL unit if exists
                if nalStart >= 0 {
                    let nalSize = offset - nalStart
                    processNALUnit(data.advanced(by: nalStart), size: nalSize, type: nalType, timestamp: timestamp)
                }

                // Start of new NAL unit
                let startCodeLen = hasStartCode4 ? 4 : 3
                nalStart = offset + startCodeLen

                // Get NAL type from first byte after start code
                if nalStart < size {
                    if codec.isH265 {
                        // H.265: NAL type is in bits 1-6 of first byte (shifted right by 1)
                        nalType = (data[nalStart] >> 1) & 0x3F
                    } else {
                        // H.264: NAL type is in bits 0-4 of first byte
                        nalType = data[nalStart] & 0x1F
                    }
                }

                offset = nalStart
            } else {
                offset += 1
            }
        }

        // Process last NAL unit
        if nalStart >= 0 && nalStart < size {
            let nalSize = size - nalStart
            processNALUnit(data.advanced(by: nalStart), size: nalSize, type: nalType, timestamp: timestamp)
        }
    }

    /// Process a single NAL unit based on its type
    private func processNALUnit(_ data: UnsafePointer<UInt8>, size: Int, type: UInt8, timestamp: UInt64) {
        guard size > 0 else { return }

        if codec.isH265 {
            processH265NALUnit(data, size: size, type: type, timestamp: timestamp)
        } else {
            processH264NALUnit(data, size: size, type: type, timestamp: timestamp)
        }
    }

    /// Process H.265 NAL unit
    private func processH265NALUnit(_ data: UnsafePointer<UInt8>, size: Int, type: UInt8, timestamp: UInt64) {
        switch type {
        case 32: // VPS
            logInfo("VideoDecoderBridge: Received VPS (\(size) bytes)")
            pendingVPS = Data(bytes: data, count: size)
            tryInitializeDecoder()

        case 33: // SPS
            logInfo("VideoDecoderBridge: Received SPS (\(size) bytes)")
            pendingSPS = Data(bytes: data, count: size)
            tryInitializeDecoder()

        case 34: // PPS
            logInfo("VideoDecoderBridge: Received PPS (\(size) bytes)")
            pendingPPS = Data(bytes: data, count: size)
            tryInitializeDecoder()

        default:
            // Video frame data - forward to decoder
            if decoder != nil {
                // Convert to AVCC format (4-byte length prefix instead of start code)
                var avccData = Data(capacity: size + 4)
                var lengthBE = UInt32(size).bigEndian
                avccData.append(Data(bytes: &lengthBE, count: 4))
                avccData.append(Data(bytes: data, count: size))

                avccData.withUnsafeBytes { ptr in
                    if let baseAddress = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) {
                        decoder?.decodeFrame(baseAddress, size: avccData.count, timestamp: timestamp)
                    }
                }
            }
        }
    }

    /// Process H.264 NAL unit
    private func processH264NALUnit(_ data: UnsafePointer<UInt8>, size: Int, type: UInt8, timestamp: UInt64) {
        switch type {
        case 7: // SPS
            logInfo("VideoDecoderBridge: Received SPS (\(size) bytes)")
            pendingSPS = Data(bytes: data, count: size)
            tryInitializeDecoder()

        case 8: // PPS
            logInfo("VideoDecoderBridge: Received PPS (\(size) bytes)")
            pendingPPS = Data(bytes: data, count: size)
            tryInitializeDecoder()

        default:
            // Video frame data - forward to decoder
            if decoder != nil {
                // Convert to AVCC format (4-byte length prefix instead of start code)
                var avccData = Data(capacity: size + 4)
                var lengthBE = UInt32(size).bigEndian
                avccData.append(Data(bytes: &lengthBE, count: 4))
                avccData.append(Data(bytes: data, count: size))

                avccData.withUnsafeBytes { ptr in
                    if let baseAddress = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) {
                        decoder?.decodeFrame(baseAddress, size: avccData.count, timestamp: timestamp)
                    }
                }
            }
        }
    }

    /// Shutdown decoder
    func shutdown() {
        initLock.lock()
        decoder?.shutdown()
        decoder = nil
        pendingSPS = nil
        pendingPPS = nil
        pendingVPS = nil
        initLock.unlock()
    }

    // MARK: - Private Methods

    /// Try to initialize decoder when all parameter sets are available
    private func tryInitializeDecoder() {
        // Check if we have required parameter sets
        guard let sps = pendingSPS, let pps = pendingPPS else {
            return
        }

        // For H.265, we also need VPS
        if codec.isH265 && pendingVPS == nil {
            return
        }

        // Create decoder if needed
        if decoder == nil {
            decoder = VideoToolboxDecoder(codec: codec, width: width, height: height)

            // Connect decoded frames to renderer
            decoder?.onFrameDecoded = { [weak self] pixelBuffer, _ in
                self?.renderer?.submitFrame(pixelBuffer)
            }
            
            // [satisfies] AC-085
            decoder?.onDecodeTimeRecorded = { [weak self] durationMs in
                self?.onDecodeTimeRecorded?(durationMs)
            }
        }

        // Initialize with parameter sets
        do {
            try decoder?.initialize(sps: sps, pps: pps, vps: pendingVPS)
            logInfo("VideoDecoderBridge: Decoder initialized")
        } catch {
            logError("VideoDecoderBridge: Failed to initialize decoder: \(error)")
        }
    }
}
