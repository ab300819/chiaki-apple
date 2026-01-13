import Foundation

/// Stream settings model
struct StreamSettings: Codable, Equatable {
    var resolution: Resolution = .r1080p
    var frameRate: FrameRate = .fps60
    var bitrate: Int = 15000 // kbps
    var codec: VideoCodec = .h265
    var hdrEnabled: Bool = false

    enum Resolution: String, Codable, CaseIterable, Identifiable {
        case r540p = "540p"
        case r720p = "720p"
        case r1080p = "1080p"
        
        var id: String { rawValue }

        var width: Int {
            switch self {
            case .r540p: return 960
            case .r720p: return 1280
            case .r1080p: return 1920
            }
        }

        var height: Int {
            switch self {
            case .r540p: return 540
            case .r720p: return 720
            case .r1080p: return 1080
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
