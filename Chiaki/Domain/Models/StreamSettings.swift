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
    var hdrEnabled: Bool = false
    
    var volume: Double = 1.0
    var microphoneEnabled: Bool = false
    
    var hapticFeedbackEnabled: Bool = true
    var isTouchControllerEnabled: Bool = true

    enum CodingKeys: String, CodingKey {
        case localProfile, remoteProfile, codec, hdrEnabled, volume, microphoneEnabled, hapticFeedbackEnabled, isTouchControllerEnabled
        case resolution, frameRate, bitrate
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
        self.hdrEnabled = (try? container.decode(Bool.self, forKey: .hdrEnabled)) ?? false
        self.volume = (try? container.decode(Double.self, forKey: .volume)) ?? 1.0
        self.microphoneEnabled = (try? container.decode(Bool.self, forKey: .microphoneEnabled)) ?? false
        self.hapticFeedbackEnabled = (try? container.decode(Bool.self, forKey: .hapticFeedbackEnabled)) ?? true
        self.isTouchControllerEnabled = (try? container.decode(Bool.self, forKey: .isTouchControllerEnabled)) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(localProfile, forKey: .localProfile)
        try container.encode(remoteProfile, forKey: .remoteProfile)
        try container.encode(codec, forKey: .codec)
        try container.encode(hdrEnabled, forKey: .hdrEnabled)
        try container.encode(volume, forKey: .volume)
        try container.encode(microphoneEnabled, forKey: .microphoneEnabled)
        try container.encode(hapticFeedbackEnabled, forKey: .hapticFeedbackEnabled)
        try container.encode(isTouchControllerEnabled, forKey: .isTouchControllerEnabled)
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
}
