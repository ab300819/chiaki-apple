// SPDX-License-Identifier: AGPL-3.0-only
//
// VideoSettingsViewModel.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// ViewModel for video/HDR settings
//
// @requirement F-027 - UI 层 MVVM 合规重构
// @satisfies AC-093 - VideoSettingsViewModel

import Foundation
import Observation

/// HDR Peak brightness mode
enum HDRPeakMode: Int, CaseIterable, Identifiable {
    case auto = 0
    case manual = 1

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .auto: return String(localized: "settings.video.auto")
        case .manual: return String(localized: "settings.video.manual")
        }
    }
}

/// ViewModel for video/HDR settings
/// @requirement F-027 - UI 层 MVVM 合规重构
/// @satisfies AC-093 - VideoSettingsViewModel
@Observable
@MainActor
final class VideoSettingsViewModel {
    // MARK: - Dependencies

    private let settingsStore: SettingsStore

    // MARK: - HDR Settings

    /// Whether HDR is enabled
    var hdrEnabled: Bool {
        get { settingsStore.streamSettings.hdrEnabled }
        set { settingsStore.streamSettings.hdrEnabled = newValue }
    }

    /// HDR peak brightness in nits (Double for slider binding)
    var hdrPeakNits: Double {
        get { Double(settingsStore.streamSettings.hdrTargetPeakNits) }
        set { settingsStore.streamSettings.hdrTargetPeakNits = Int(newValue) }
    }

    /// HDR peak mode (auto/manual)
    var hdrPeakMode: HDRPeakMode {
        get { settingsStore.streamSettings.hdrTargetPeakNits == 0 ? .auto : .manual }
        set {
            if newValue == .auto {
                settingsStore.streamSettings.hdrTargetPeakNits = 0
            } else if settingsStore.streamSettings.hdrTargetPeakNits == 0 {
                // Set default manual value
                settingsStore.streamSettings.hdrTargetPeakNits = 1000
            }
        }
    }

    /// EDR intensity multiplier (0.5 - 2.0)
    var edrIntensity: Float = 1.0

    // MARK: - Computed Properties

    /// Whether to show EDR intensity slider
    var shouldShowEDRIntensity: Bool {
        settingsStore.streamSettings.hdrEnabled
    }

    /// Whether to show color space picker
    var shouldShowColorSpace: Bool {
        settingsStore.streamSettings.hdrEnabled
    }

    // MARK: - Initialization

    /// Initialize with settings store dependency
    /// - Parameter settingsStore: Settings store (defaults to shared instance)
    init(settingsStore: SettingsStore? = nil) {
        self.settingsStore = settingsStore ?? SettingsStore.shared
    }

    // MARK: - Validation

    /// Validate current settings
    /// - Returns: true if settings are valid
    func validateSettings() -> Bool {
        // Peak nits must be 0 (auto) or within valid range (100-10000)
        let peakNits = settingsStore.streamSettings.hdrTargetPeakNits
        if peakNits != 0 && (peakNits < 100 || peakNits > 10000) {
            return false
        }

        // EDR intensity must be in valid range
        if edrIntensity < 0.5 || edrIntensity > 2.0 {
            return false
        }

        return true
    }
}
