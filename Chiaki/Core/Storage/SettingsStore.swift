import Foundation
import Observation

/// Settings storage managing persistence to UserDefaults
@Observable
class SettingsStore {
    var streamSettings: StreamSettings {
        didSet {
            saveSettings()
        }
    }
    
    var useRemoteProfile: Bool {
        didSet {
            userDefaults.set(useRemoteProfile, forKey: "use_remote_profile")
        }
    }
    
    private let key = "stream_settings"
    private let userDefaults: UserDefaults
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.useRemoteProfile = userDefaults.bool(forKey: "use_remote_profile")
        
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
        if useRemoteProfile {
            streamSettings.remoteProfile.resolution = resolution
        } else {
            streamSettings.localProfile.resolution = resolution
        }
    }
    
    func updateFrameRate(_ frameRate: StreamSettings.FrameRate) {
        if useRemoteProfile {
            streamSettings.remoteProfile.frameRate = frameRate
        } else {
            streamSettings.localProfile.frameRate = frameRate
        }
    }
    
    func updateBitrate(_ bitrate: Int) {
        if useRemoteProfile {
            streamSettings.remoteProfile.bitrate = bitrate
        } else {
            streamSettings.localProfile.bitrate = bitrate
        }
    }
    
    func updateCodec(_ codec: StreamSettings.VideoCodec) {
        streamSettings.codec = codec
    }
    
    func updateHdrEnabled(_ enabled: Bool) {
        streamSettings.hdrEnabled = enabled
    }

    func updateVolume(_ volume: Double) {
        streamSettings.volume = max(0.0, min(1.0, volume))
    }

    func updateDisplayMode(_ mode: StreamSettings.DisplayMode) {
        streamSettings.displayMode = mode
    }

    func updateZoomFactor(_ factor: Double) {
        streamSettings.zoomFactor = max(1.0, min(2.0, factor))
    }

    // MARK: - Import/Export

    /// Export settings as JSON data
    func exportSettings() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(streamSettings)
    }

    /// Import settings from JSON data
    func importSettings(from data: Data) throws {
        let decoder = JSONDecoder()
        let imported = try decoder.decode(StreamSettings.self, from: data)
        streamSettings = imported
    }

    /// Reset settings to defaults
    func resetToDefaults() {
        streamSettings = StreamSettings()
    }
}
