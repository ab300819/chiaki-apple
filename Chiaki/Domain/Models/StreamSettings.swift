import Foundation

/// Stream settings model
struct StreamSettings: Codable, Equatable {
    struct StreamProfile: Codable, Equatable {
        var resolution: Resolution = .r1080p
        var frameRate: FrameRate = .fps60
        var bitrate: Int = 15000 // kbps
    }

    var localProfile: StreamProfile = StreamProfile()
    var remoteProfile: StreamProfile = StreamProfile(bitrate: 10000)
    
    var codec: VideoCodec = .h265
    var hardwareDecodingEnabled: Bool = true
    var colorSpace: ColorSpace = .bt709
    var hdrEnabled: Bool = false

    // HDR Fine-tuning (only used when hdrEnabled is true)
    // 0 = Auto, 10-10000 = manual nits value
    var hdrTargetPeakNits: Int = 0
    // 0 = Auto, -1 = Infinity, 10-1000000 = manual contrast ratio
    var hdrTargetContrast: Int = 0
    
    var volume: Double = 1.0
    var audioBufferSize: Int = 20 // ms
    var microphoneEnabled: Bool = false

    var hapticFeedbackEnabled: Bool = true
    var isTouchControllerEnabled: Bool = true

    var displayMode: DisplayMode = .normal
    var zoomFactor: Double = 1.0

    // Controller settings
    var stickDeadzone: Double = 0.1 // 0.0 - 0.3
    var swapCrossCircle: Bool = false // Japanese layout swap
    var touchControllerOpacity: Double = 0.7 // 0.3 - 1.0
    var motionControlsEnabled: Bool = false
    var showControllerHints: Bool = true
    var vrrEnabled: Bool = true

    enum CodingKeys: String, CodingKey {
        case localProfile, remoteProfile, codec, hardwareDecodingEnabled, colorSpace, hdrEnabled
        case hdrTargetPeakNits, hdrTargetContrast
        case volume, audioBufferSize, microphoneEnabled, hapticFeedbackEnabled, isTouchControllerEnabled
        case resolution, frameRate, bitrate, displayMode, zoomFactor
        case stickDeadzone, swapCrossCircle, touchControllerOpacity, motionControlsEnabled, showControllerHints, vrrEnabled
    }

    /// Video display mode for streaming
    enum DisplayMode: String, Codable, CaseIterable, Identifiable {
        case normal = "Fit"
        case stretch = "Stretch"
        case zoom = "Zoom"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .normal: return "Fit (letterbox)"
            case .stretch: return "Stretch to fill"
            case .zoom: return "Zoom to fill"
            }
        }

        var iconName: String {
            switch self {
            case .normal: return "rectangle.arrowtriangle.2.inward"
            case .stretch: return "arrow.left.and.right"
            case .zoom: return "arrow.up.left.and.arrow.down.right"
            }
        }
    }

    /// Video rendering preset
    enum VideoPreset: String, Codable, CaseIterable, Identifiable {
        case `default` = "Default"
        case highQuality = "High Quality"
        case performance = "Performance"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .default: return "Balanced quality and performance"
            case .highQuality: return "Best visual quality, higher GPU usage"
            case .performance: return "Optimized for smooth playback"
            }
        }

        var iconName: String {
            switch self {
            case .default: return "sparkles"
            case .highQuality: return "star.fill"
            case .performance: return "hare.fill"
            }
        }
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let local = try? container.decode(StreamProfile.self, forKey: .localProfile),
           let remote = try? container.decode(StreamProfile.self, forKey: .remoteProfile) {
            self.localProfile = local
            self.remoteProfile = remote
        } else {
            let res = (try? container.decode(Resolution.self, forKey: .resolution)) ?? .r1080p
            let fps = (try? container.decode(FrameRate.self, forKey: .frameRate)) ?? .fps60
            let bit = (try? container.decode(Int.self, forKey: .bitrate)) ?? 15000
            let profile = StreamProfile(resolution: res, frameRate: fps, bitrate: bit)
            self.localProfile = profile
            self.remoteProfile = profile
        }
        
        self.codec = (try? container.decode(VideoCodec.self, forKey: .codec)) ?? .h265
        self.hardwareDecodingEnabled = (try? container.decode(Bool.self, forKey: .hardwareDecodingEnabled)) ?? true
        self.colorSpace = (try? container.decode(ColorSpace.self, forKey: .colorSpace)) ?? .bt709
        self.hdrEnabled = (try? container.decode(Bool.self, forKey: .hdrEnabled)) ?? false
        self.hdrTargetPeakNits = (try? container.decode(Int.self, forKey: .hdrTargetPeakNits)) ?? 0
        self.hdrTargetContrast = (try? container.decode(Int.self, forKey: .hdrTargetContrast)) ?? 0
        self.volume = (try? container.decode(Double.self, forKey: .volume)) ?? 1.0
        self.audioBufferSize = (try? container.decode(Int.self, forKey: .audioBufferSize)) ?? 20
        self.microphoneEnabled = (try? container.decode(Bool.self, forKey: .microphoneEnabled)) ?? false
        self.hapticFeedbackEnabled = (try? container.decode(Bool.self, forKey: .hapticFeedbackEnabled)) ?? true
        self.isTouchControllerEnabled = (try? container.decode(Bool.self, forKey: .isTouchControllerEnabled)) ?? true
        self.displayMode = (try? container.decode(DisplayMode.self, forKey: .displayMode)) ?? .normal
        self.zoomFactor = (try? container.decode(Double.self, forKey: .zoomFactor)) ?? 1.0
        self.stickDeadzone = (try? container.decode(Double.self, forKey: .stickDeadzone)) ?? 0.1
        self.swapCrossCircle = (try? container.decode(Bool.self, forKey: .swapCrossCircle)) ?? false
        self.touchControllerOpacity = (try? container.decode(Double.self, forKey: .touchControllerOpacity)) ?? 0.7
        self.motionControlsEnabled = (try? container.decode(Bool.self, forKey: .motionControlsEnabled)) ?? false
        self.showControllerHints = (try? container.decode(Bool.self, forKey: .showControllerHints)) ?? true
        self.vrrEnabled = (try? container.decode(Bool.self, forKey: .vrrEnabled)) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(localProfile, forKey: .localProfile)
        try container.encode(remoteProfile, forKey: .remoteProfile)
        try container.encode(codec, forKey: .codec)
        try container.encode(hardwareDecodingEnabled, forKey: .hardwareDecodingEnabled)
        try container.encode(colorSpace, forKey: .colorSpace)
        try container.encode(hdrEnabled, forKey: .hdrEnabled)
        try container.encode(hdrTargetPeakNits, forKey: .hdrTargetPeakNits)
        try container.encode(hdrTargetContrast, forKey: .hdrTargetContrast)
        try container.encode(volume, forKey: .volume)
        try container.encode(audioBufferSize, forKey: .audioBufferSize)
        try container.encode(microphoneEnabled, forKey: .microphoneEnabled)
        try container.encode(hapticFeedbackEnabled, forKey: .hapticFeedbackEnabled)
        try container.encode(isTouchControllerEnabled, forKey: .isTouchControllerEnabled)
        try container.encode(displayMode, forKey: .displayMode)
        try container.encode(zoomFactor, forKey: .zoomFactor)
        try container.encode(stickDeadzone, forKey: .stickDeadzone)
        try container.encode(swapCrossCircle, forKey: .swapCrossCircle)
        try container.encode(touchControllerOpacity, forKey: .touchControllerOpacity)
        try container.encode(motionControlsEnabled, forKey: .motionControlsEnabled)
        try container.encode(showControllerHints, forKey: .showControllerHints)
        try container.encode(vrrEnabled, forKey: .vrrEnabled)
    }

    enum Resolution: String, Codable, CaseIterable, Identifiable {
        case r540p = "540p"
        case r720p = "720p"
        case r1080p = "1080p"
        case r2160p = "4K"

        var id: String { rawValue }

        var width: Int {
            switch self {
            case .r540p: return 960
            case .r720p: return 1280
            case .r1080p: return 1920
            case .r2160p: return 3840
            }
        }

        var height: Int {
            switch self {
            case .r540p: return 540
            case .r720p: return 720
            case .r1080p: return 1080
            case .r2160p: return 2160
            }
        }
    }

    enum FrameRate: Int, Codable, CaseIterable, Identifiable {
        case fps30 = 30
        case fps60 = 60
        
        var id: Int { rawValue }
    }

    enum VideoCodec: String, Codable, CaseIterable, Identifiable {
        case h264 = "H.264"
        case h265 = "H.265 (HEVC)"
        
        var id: String { rawValue }
    }

    /// Color space for YUV to RGB conversion
    /// Maps to Metal shader's colorSpace uniform (0, 1, 2)
    enum ColorSpace: UInt32, Codable, CaseIterable, Identifiable {
        case bt709 = 0   // HD content (PS4/PS5 default)
        case bt601 = 1   // SD content (legacy)
        case bt2020 = 2  // HDR/Wide Color Gamut

        var id: UInt32 { rawValue }

        var displayName: String {
            switch self {
            case .bt709: return "BT.709 (SDR)"
            case .bt601: return "BT.601 (SD)"
            case .bt2020: return "BT.2020 (HDR)"
            }
        }
    }
}
