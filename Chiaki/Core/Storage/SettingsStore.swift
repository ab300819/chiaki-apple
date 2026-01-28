import Foundation
import Observation

/// Settings storage managing persistence to UserDefaults
@Observable
class SettingsStore {
    @MainActor static let shared = SettingsStore()

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

    // MARK: - Keyboard Mapping Settings (macOS only)

    #if os(macOS)
    /// Whether keyboard input is enabled for controller emulation
    var keyboardInputEnabled: Bool {
        didSet {
            userDefaults.set(keyboardInputEnabled, forKey: Keys.keyboardInputEnabled)
        }
    }

    /// Keyboard to controller button mappings
    var keyboardMappings: KeyboardMappings {
        didSet {
            saveKeyboardMappings()
        }
    }
    #endif

    // MARK: - Types

    /// Action to perform when disconnecting
    enum DisconnectAction: Int, CaseIterable, Identifiable {
        case doNothing = 0
        case enterSleepMode = 1
        case ask = 2

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .doNothing: return String(localized: "disconnectAction.doNothing")
            case .enterSleepMode: return String(localized: "disconnectAction.enterSleepMode")
            case .ask: return String(localized: "disconnectAction.ask")
            }
        }

        var description: String {
            switch self {
            case .doNothing: return String(localized: "disconnectAction.doNothingDescription")
            case .enterSleepMode: return String(localized: "disconnectAction.enterSleepModeDescription")
            case .ask: return String(localized: "disconnectAction.askDescription")
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
            case .doNothing: return String(localized: "suspendAction.doNothing")
            case .enterSleepMode: return String(localized: "suspendAction.enterSleepMode")
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
        #if os(macOS)
        static let keyboardInputEnabled = "keyboard_input_enabled"
        static let keyboardMappings = "keyboard_mappings"
        #endif
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

        #if os(macOS)
        // Load keyboard input settings (default: enabled)
        self.keyboardInputEnabled = userDefaults.object(forKey: Keys.keyboardInputEnabled) as? Bool ?? true

        // Load keyboard mappings
        if let data = userDefaults.data(forKey: Keys.keyboardMappings),
           let decoded = try? JSONDecoder().decode(KeyboardMappings.self, from: data) {
            self.keyboardMappings = decoded
        } else {
            self.keyboardMappings = KeyboardMappings.defaultMappings
        }
        #endif
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
        #if os(macOS)
        keyboardMappings = KeyboardMappings.defaultMappings
        keyboardInputEnabled = true
        #endif
    }

    #if os(macOS)
    private func saveKeyboardMappings() {
        if let encoded = try? JSONEncoder().encode(keyboardMappings) {
            userDefaults.set(encoded, forKey: Keys.keyboardMappings)
        }
    }
    #endif
}

// MARK: - Keyboard Mappings (macOS only)

#if os(macOS)
/// Represents a single keyboard key mapping to a controller button
struct KeyboardMapping: Codable, Equatable, Identifiable {
    var id: String { button.rawValue }
    let button: MappableButton
    var keyCode: UInt16?
    var keyName: String?

    /// Check if this mapping has a key assigned
    var hasMapping: Bool {
        keyCode != nil
    }
}

/// All keyboard mappings for controller emulation
struct KeyboardMappings: Codable, Equatable {
    var cross: KeyboardMapping
    var circle: KeyboardMapping
    var square: KeyboardMapping
    var triangle: KeyboardMapping
    var l1: KeyboardMapping
    var r1: KeyboardMapping
    var l2: KeyboardMapping
    var r2: KeyboardMapping
    var l3: KeyboardMapping
    var r3: KeyboardMapping
    var dpadUp: KeyboardMapping
    var dpadDown: KeyboardMapping
    var dpadLeft: KeyboardMapping
    var dpadRight: KeyboardMapping
    var options: KeyboardMapping
    var share: KeyboardMapping
    var touchpad: KeyboardMapping
    var ps: KeyboardMapping

    /// All mappings as an array for iteration
    var allMappings: [KeyboardMapping] {
        [cross, circle, square, triangle, l1, r1, l2, r2, l3, r3,
         dpadUp, dpadDown, dpadLeft, dpadRight, options, share, touchpad, ps]
    }

    /// Get mapping for a specific button
    func mapping(for button: MappableButton) -> KeyboardMapping {
        switch button {
        case .cross: return cross
        case .circle: return circle
        case .square: return square
        case .triangle: return triangle
        case .l1: return l1
        case .r1: return r1
        case .l2: return l2
        case .r2: return r2
        case .l3: return l3
        case .r3: return r3
        case .dpadUp: return dpadUp
        case .dpadDown: return dpadDown
        case .dpadLeft: return dpadLeft
        case .dpadRight: return dpadRight
        case .options: return options
        case .share: return share
        case .touchpad: return touchpad
        case .ps: return ps
        }
    }

    /// Update mapping for a specific button
    mutating func setMapping(for button: MappableButton, keyCode: UInt16?, keyName: String?) {
        let newMapping = KeyboardMapping(button: button, keyCode: keyCode, keyName: keyName)
        switch button {
        case .cross: cross = newMapping
        case .circle: circle = newMapping
        case .square: square = newMapping
        case .triangle: triangle = newMapping
        case .l1: l1 = newMapping
        case .r1: r1 = newMapping
        case .l2: l2 = newMapping
        case .r2: r2 = newMapping
        case .l3: l3 = newMapping
        case .r3: r3 = newMapping
        case .dpadUp: dpadUp = newMapping
        case .dpadDown: dpadDown = newMapping
        case .dpadLeft: dpadLeft = newMapping
        case .dpadRight: dpadRight = newMapping
        case .options: options = newMapping
        case .share: share = newMapping
        case .touchpad: touchpad = newMapping
        case .ps: ps = newMapping
        }
    }

    /// Default keyboard mappings
    static let defaultMappings = KeyboardMappings(
        cross: KeyboardMapping(button: .cross, keyCode: 40, keyName: "K"),           // K
        circle: KeyboardMapping(button: .circle, keyCode: 37, keyName: "L"),         // L
        square: KeyboardMapping(button: .square, keyCode: 38, keyName: "J"),         // J
        triangle: KeyboardMapping(button: .triangle, keyCode: 34, keyName: "I"),     // I
        l1: KeyboardMapping(button: .l1, keyCode: 12, keyName: "Q"),                 // Q
        r1: KeyboardMapping(button: .r1, keyCode: 14, keyName: "E"),                 // E
        l2: KeyboardMapping(button: .l2, keyCode: 6, keyName: "Z"),                  // Z
        r2: KeyboardMapping(button: .r2, keyCode: 7, keyName: "X"),                  // X
        l3: KeyboardMapping(button: .l3, keyCode: 15, keyName: "R"),                 // R
        r3: KeyboardMapping(button: .r3, keyCode: 17, keyName: "T"),                 // T
        dpadUp: KeyboardMapping(button: .dpadUp, keyCode: 126, keyName: "↑"),        // Arrow Up
        dpadDown: KeyboardMapping(button: .dpadDown, keyCode: 125, keyName: "↓"),    // Arrow Down
        dpadLeft: KeyboardMapping(button: .dpadLeft, keyCode: 123, keyName: "←"),    // Arrow Left
        dpadRight: KeyboardMapping(button: .dpadRight, keyCode: 124, keyName: "→"),  // Arrow Right
        options: KeyboardMapping(button: .options, keyCode: 36, keyName: "Return"),  // Return
        share: KeyboardMapping(button: .share, keyCode: 49, keyName: "Space"),       // Space
        touchpad: KeyboardMapping(button: .touchpad, keyCode: 48, keyName: "Tab"),   // Tab
        ps: KeyboardMapping(button: .ps, keyCode: 53, keyName: "Esc")                // Escape
    )
}

/// Buttons that can be mapped to keyboard keys
enum MappableButton: String, Codable, CaseIterable, Identifiable {
    case cross, circle, square, triangle
    case l1, r1, l2, r2, l3, r3
    case dpadUp, dpadDown, dpadLeft, dpadRight
    case options, share, touchpad, ps

    var id: String { rawValue }

    /// Display name for the button
    var displayName: String {
        switch self {
        case .cross: return "✕ Cross"
        case .circle: return "○ Circle"
        case .square: return "□ Square"
        case .triangle: return "△ Triangle"
        case .l1: return "L1"
        case .r1: return "R1"
        case .l2: return "L2"
        case .r2: return "R2"
        case .l3: return "L3"
        case .r3: return "R3"
        case .dpadUp: return "D-Pad Up"
        case .dpadDown: return "D-Pad Down"
        case .dpadLeft: return "D-Pad Left"
        case .dpadRight: return "D-Pad Right"
        case .options: return "Options"
        case .share: return "Share"
        case .touchpad: return "Touchpad"
        case .ps: return "PS Button"
        }
    }

    /// Category for grouping in UI
    var category: ButtonCategory {
        switch self {
        case .cross, .circle, .square, .triangle: return .face
        case .l1, .r1, .l2, .r2, .l3, .r3: return .shoulder
        case .dpadUp, .dpadDown, .dpadLeft, .dpadRight: return .dpad
        case .options, .share, .touchpad, .ps: return .system
        }
    }

    enum ButtonCategory: String, CaseIterable {
        case face = "Face Buttons"
        case shoulder = "Shoulder Buttons"
        case dpad = "D-Pad"
        case system = "System Buttons"

        var buttons: [MappableButton] {
            MappableButton.allCases.filter { $0.category == self }
        }
    }
}
#endif
