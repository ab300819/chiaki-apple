// SPDX-License-Identifier: AGPL-3.0-only
//
// HDRConfiguration.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Unified HDR configuration structure for centralized HDR settings management
//
// @requirement F-025 - HDR 渲染管线优化
// @requirement F-026 - 渲染模块解耦重构
// @satisfies AC-088 - HDR 配置统一

import Foundation

// MARK: - HDR Color Space

/// Color space options for video rendering
/// Raw values align with Metal shader constants (VideoUniforms.colorSpace)
/// @satisfies AC-088
enum HDRColorSpace: UInt32, Codable, CaseIterable, Identifiable, Sendable {
    case bt709 = 0   // HD content (PS4/PS5 default, SDR)
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

    /// Whether this color space is HDR-capable
    var isHDRCapable: Bool {
        self == .bt2020
    }
}

// MARK: - HDR Color Range

/// Color range options for video rendering
/// Raw values align with Metal shader constants (VideoUniforms.colorRange)
/// @satisfies AC-088
enum HDRColorRange: UInt32, Codable, CaseIterable, Identifiable, Sendable {
    case video = 0   // Limited range (16-235 for Y, 16-240 for UV)
    case full = 1    // Full range (0-255)

    var id: UInt32 { rawValue }

    var displayName: String {
        switch self {
        case .video: return "Video Range (Limited)"
        case .full: return "Full Range"
        }
    }
}

// MARK: - Tonemap Mode

/// Tone mapping modes for HDR→SDR conversion
/// Raw values align with Metal shader constants
/// @satisfies AC-088
enum TonemapMode: UInt32, Codable, CaseIterable, Identifiable, Sendable {
    case passthrough = 0  // No tone mapping, direct EDR output (for HDR displays)
    case aces = 1         // ACES Filmic tone mapping (for SDR displays)

    var id: UInt32 { rawValue }

    var displayName: String {
        switch self {
        case .passthrough: return "Passthrough (HDR)"
        case .aces: return "ACES Filmic (SDR)"
        }
    }
}

// MARK: - HDR Configuration

/// Unified HDR configuration structure
/// Centralizes all HDR-related settings for consistent management across the rendering pipeline
/// @requirement F-025 - HDR 渲染管线优化
/// @requirement F-026 - 渲染模块解耦重构
/// @satisfies AC-088 - HDR 配置统一
struct HDRConfiguration: Codable, Equatable, Sendable {

    // MARK: - Properties

    /// Whether HDR rendering is enabled
    var enabled: Bool

    /// EDR intensity multiplier (0.5 - 2.0, default 1.0)
    /// Controls the strength of Extended Dynamic Range output
    var edrIntensity: Float

    /// Color space for video content
    var colorSpace: HDRColorSpace

    /// Color range (video/full)
    var colorRange: HDRColorRange

    /// Tone mapping mode for HDR→SDR conversion
    var tonemapMode: TonemapMode

    /// Whether to apply Rec.2020 → Display P3 gamut mapping
    var gamutMappingEnabled: Bool

    // MARK: - Computed Properties

    /// Whether the current configuration represents active HDR mode
    /// True only when HDR is enabled AND using BT.2020 color space
    var isHDR: Bool {
        enabled && colorSpace == .bt2020
    }

    // MARK: - Initializer

    /// Creates an HDR configuration with specified parameters
    /// - Parameters:
    ///   - enabled: Whether HDR is enabled (default: false)
    ///   - edrIntensity: EDR intensity multiplier (default: 1.0)
    ///   - colorSpace: Color space (default: .bt709)
    ///   - colorRange: Color range (default: .video)
    ///   - tonemapMode: Tone mapping mode (default: .passthrough)
    ///   - gamutMappingEnabled: Enable gamut mapping (default: true)
    init(
        enabled: Bool = false,
        edrIntensity: Float = 1.0,
        colorSpace: HDRColorSpace = .bt709,
        colorRange: HDRColorRange = .video,
        tonemapMode: TonemapMode = .passthrough,
        gamutMappingEnabled: Bool = true
    ) {
        self.enabled = enabled
        self.edrIntensity = edrIntensity
        self.colorSpace = colorSpace
        self.colorRange = colorRange
        self.tonemapMode = tonemapMode
        self.gamutMappingEnabled = gamutMappingEnabled
    }

    // MARK: - Static Presets

    /// Standard SDR configuration preset
    /// @satisfies AC-088
    static let sdr = HDRConfiguration(
        enabled: false,
        edrIntensity: 1.0,
        colorSpace: .bt709,
        colorRange: .video,
        tonemapMode: .passthrough,
        gamutMappingEnabled: false
    )

    /// Standard HDR configuration preset
    /// @satisfies AC-088
    static let hdr = HDRConfiguration(
        enabled: true,
        edrIntensity: 1.0,
        colorSpace: .bt2020,
        colorRange: .video,
        tonemapMode: .passthrough,
        gamutMappingEnabled: true
    )

    // MARK: - Convenience Methods

    /// Creates a configuration with HDR enabled for the specified color space
    /// - Parameter colorSpace: The color space to use (defaults to .bt2020)
    /// - Returns: An HDR-enabled configuration
    static func hdr(with colorSpace: HDRColorSpace = .bt2020) -> HDRConfiguration {
        HDRConfiguration(
            enabled: true,
            edrIntensity: 1.0,
            colorSpace: colorSpace,
            colorRange: .video,
            tonemapMode: .passthrough,
            gamutMappingEnabled: colorSpace == .bt2020
        )
    }

    /// Creates a copy with modified EDR intensity
    /// - Parameter intensity: The new EDR intensity (clamped to 0.5-2.0)
    /// - Returns: A new configuration with the specified intensity
    func withEDRIntensity(_ intensity: Float) -> HDRConfiguration {
        var copy = self
        copy.edrIntensity = max(0.5, min(2.0, intensity))
        return copy
    }

    /// Creates a copy with tone mapping mode for SDR displays
    /// - Returns: A configuration suitable for SDR display output
    func forSDRDisplay() -> HDRConfiguration {
        var copy = self
        copy.tonemapMode = .aces
        return copy
    }
}

// MARK: - Debug Description

extension HDRConfiguration: CustomDebugStringConvertible {
    var debugDescription: String {
        """
        HDRConfiguration(
            enabled: \(enabled),
            edrIntensity: \(edrIntensity),
            colorSpace: \(colorSpace.displayName),
            colorRange: \(colorRange.displayName),
            tonemapMode: \(tonemapMode.displayName),
            gamutMappingEnabled: \(gamutMappingEnabled),
            isHDR: \(isHDR)
        )
        """
    }
}
