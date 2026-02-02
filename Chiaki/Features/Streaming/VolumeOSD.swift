// SPDX-License-Identifier: AGPL-3.0-only
//
// VolumeOSD.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// On-screen display for volume adjustment

import SwiftUI

/**
 * Volume On-Screen Display
 * @requirement F-022 - 手柄操控 UI/UX 优化
 * @satisfies AC-066 - 流媒体中音量快捷调节
 */
struct VolumeOSD: View {
    /// Current volume level (0.0-1.0)
    let volume: Double

    /// Whether the OSD is visible
    @Binding var isVisible: Bool

    /// Auto-hide timer duration (seconds)
    static let autoHideDelay: TimeInterval = 2.0

    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                Image(systemName: volumeIconName)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 24)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.3))

                        // Fill track
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white)
                            .frame(width: geometry.size.width * volume)
                    }
                }
                .frame(width: 120, height: 8)

                Text(volumePercentage)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 48, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(L10n.Accessibility.volumeLevel(Int(volume * 100)))
        }
    }

    // MARK: - Computed Properties

    private var volumeIconName: String {
        if volume == 0 {
            return "speaker.slash.fill"
        } else if volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if volume < 0.67 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }

    private var volumePercentage: String {
        "\(Int(volume * 100))%"
    }
}

// MARK: - Preview

#Preview("Volume OSD - Medium") {
    ZStack {
        Color.black.ignoresSafeArea()
        VolumeOSD(volume: 0.5, isVisible: .constant(true))
    }
}

#Preview("Volume OSD - Muted") {
    ZStack {
        Color.black.ignoresSafeArea()
        VolumeOSD(volume: 0.0, isVisible: .constant(true))
    }
}

#Preview("Volume OSD - Max") {
    ZStack {
        Color.black.ignoresSafeArea()
        VolumeOSD(volume: 1.0, isVisible: .constant(true))
    }
}
