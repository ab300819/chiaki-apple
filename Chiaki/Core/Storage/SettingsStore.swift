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

    // MARK: - Auto-Connect Settings

    /// Whether auto-connect is enabled on app launch
    var autoConnectEnabled: Bool {
        didSet {
            userDefaults.set(autoConnectEnabled, forKey: Keys.autoConnectEnabled)
        }
    }

    /// The host ID to auto-connect to (nil means last connected host)
    var autoConnectHostId: UUID? {
        didSet {
            if let id = autoConnectHostId {
                userDefaults.set(id.uuidString, forKey: Keys.autoConnectHostId)
            } else {
                userDefaults.removeObject(forKey: Keys.autoConnectHostId)
            }
        }
    }

    /// Whether to wake the console before auto-connecting
    var autoConnectWakeUp: Bool {
        didSet {
            userDefaults.set(autoConnectWakeUp, forKey: Keys.autoConnectWakeUp)
        }
    }

    // MARK: - Disconnect Action Settings

    /// Action to perform when disconnecting from a session
    var disconnectAction: DisconnectAction {
        didSet {
            userDefaults.set(disconnectAction.rawValue, forKey: Keys.disconnectAction)
        }
    }

    /// Action to perform when the app is suspended (backgrounded)
    var suspendAction: SuspendAction {
        didSet {
            userDefaults.set(suspendAction.rawValue, forKey: Keys.suspendAction)
        }
    }

    // MARK: - Privacy Settings

    /// Streamer mode hides sensitive information like IP addresses and MAC addresses
    var streamerModeEnabled: Bool {
        didSet {
            userDefaults.set(streamerModeEnabled, forKey: Keys.streamerMode)
        }
    }

    // MARK: - Types

    /// Action to perform when disconnecting
    enum DisconnectAction: Int, CaseIterable, Identifiable {
        case doNothing = 0
        case enterSleepMode = 1
        case ask = 2

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .doNothing: return "Do Nothing"
            case .enterSleepMode: return "Enter Rest Mode"
            case .ask: return "Ask"
            }
        }

        var description: String {
            switch self {
            case .doNothing: return "Simply disconnect without changing console state"
            case .enterSleepMode: return "Put the console into rest mode when disconnecting"
            case .ask: return "Show a dialog asking what to do"
            }
        }
    }

    /// Action to perform when app is suspended
    enum SuspendAction: Int, CaseIterable, Identifiable {
        case doNothing = 0
        case enterSleepMode = 1

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .doNothing: return "Do Nothing"
            case .enterSleepMode: return "Enter Rest Mode"
            }
        }
    }

    private struct Keys {
        static let streamSettings = "stream_settings"
        static let useRemoteProfile = "use_remote_profile"
        static let autoConnectEnabled = "auto_connect_enabled"
        static let autoConnectHostId = "auto_connect_host_id"
        static let autoConnectWakeUp = "auto_connect_wake_up"
        static let disconnectAction = "disconnect_action"
        static let suspendAction = "suspend_action"
        static let streamerMode = "streamer_mode"
    }

    private let key = "stream_settings"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.useRemoteProfile = userDefaults.bool(forKey: Keys.useRemoteProfile)
        self.autoConnectEnabled = userDefaults.bool(forKey: Keys.autoConnectEnabled)
        self.autoConnectWakeUp = userDefaults.bool(forKey: Keys.autoConnectWakeUp)

        // Load disconnect/suspend actions (default: ask for disconnect, do nothing for suspend)
        let disconnectRaw = userDefaults.object(forKey: Keys.disconnectAction) as? Int ?? DisconnectAction.ask.rawValue
        self.disconnectAction = DisconnectAction(rawValue: disconnectRaw) ?? .ask

        let suspendRaw = userDefaults.object(forKey: Keys.suspendAction) as? Int ?? SuspendAction.doNothing.rawValue
        self.suspendAction = SuspendAction(rawValue: suspendRaw) ?? .doNothing

        // Load streamer mode (default: off)
        self.streamerModeEnabled = userDefaults.bool(forKey: Keys.streamerMode)

        if let idString = userDefaults.string(forKey: Keys.autoConnectHostId),
           let uuid = UUID(uuidString: idString) {
            self.autoConnectHostId = uuid
        } else {
            self.autoConnectHostId = nil
        }

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
