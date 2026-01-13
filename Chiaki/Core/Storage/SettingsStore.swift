import Foundation
import Combine

/// Settings storage managing persistence to UserDefaults
class SettingsStore: ObservableObject {
    @Published var streamSettings: StreamSettings {
        didSet {
            saveSettings()
        }
    }
    
    private let key = "stream_settings"
    private let userDefaults: UserDefaults
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        
        if let data = userDefaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(StreamSettings.self, from: data) {
            self.streamSettings = decoded
        } else {
            self.streamSettings = StreamSettings()
        }
    }
    
    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(streamSettings) {
            userDefaults.set(encoded, forKey: key)
        }
    }
    
    // MARK: - Accessors
    
    func updateResolution(_ resolution: StreamSettings.Resolution) {
        streamSettings.resolution = resolution
    }
    
    func updateFrameRate(_ frameRate: StreamSettings.FrameRate) {
        streamSettings.frameRate = frameRate
    }
    
    func updateBitrate(_ bitrate: Int) {
        streamSettings.bitrate = bitrate
    }
    
    func updateCodec(_ codec: StreamSettings.VideoCodec) {
        streamSettings.codec = codec
    }
    
    func updateHdrEnabled(_ enabled: Bool) {
        streamSettings.hdrEnabled = enabled
    }
}
