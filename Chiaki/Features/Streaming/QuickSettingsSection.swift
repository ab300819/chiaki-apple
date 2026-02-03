// SPDX-License-Identifier: AGPL-3.0-only
//
// QuickSettingsSection.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Quick settings section for streaming control menu
// @requirement F-022 - 手柄操控 UI/UX 优化
// @satisfies AC-068 - 设置快捷入口

import SwiftUI

// MARK: - Configuration

/**
 * Configuration constants for quick settings
 * @satisfies AC-068 - 设置快捷入口
 */
enum QuickSettingsConfig {
    /// Minimum bitrate in kbps
    static let minBitrate = 5000
    /// Maximum bitrate in kbps
    static let maxBitrate = 50000
    /// Bitrate adjustment step in kbps
    static let bitrateStep = 5000

    /// Minimum volume
    static let minVolume: Double = 0.0
    /// Maximum volume
    static let maxVolume: Double = 1.0

    /// Available resolutions for quick settings (common options only)
    static let availableResolutions: [StreamSettings.Resolution] = [.r720p, .r1080p]

    /// Returns the appropriate volume icon for a given level
    /// - Parameter volume: Volume level from 0.0 to 1.0
    /// - Returns: SF Symbol name for the volume level
    static func volumeIcon(for volume: Double) -> String {
        if volume == 0 {
            return "speaker.slash"
        } else if volume <= 0.33 {
            return "speaker.wave.1"
        } else if volume <= 0.66 {
            return "speaker.wave.2"
        } else {
            return "speaker.wave.3"
        }
    }

    /// Formats bitrate for display
    /// - Parameter bitrate: Bitrate in kbps
    /// - Returns: Formatted string like "15 Mbps"
    static func formatBitrate(_ bitrate: Int) -> String {
        "\(bitrate / 1000) Mbps"
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    /// Posted when settings change requires reconnection
    static let reconnectRequired = Notification.Name("reconnectRequired")
}

// MARK: - Quick Settings Section

/**
 * Quick settings section for streaming control menu
 * Allows adjusting bitrate, volume, and resolution without disconnecting
 * @requirement F-022 - 手柄操控 UI/UX 优化
 * @satisfies AC-068 - 设置快捷入口
 */
struct QuickSettingsSection: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Binding var volume: Double
    @Binding var bitrate: Int
    var currentResolution: StreamSettings.Resolution
    var focusedControl: FocusState<StreamingControlFocus?>.Binding

    /// Pending resolution that requires reconnect to apply
    @State private var pendingResolution: StreamSettings.Resolution?
    /// Whether the settings disclosure group is expanded
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header with Disclosure
            Button(action: {
                HapticFeedback.button()
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Label(L10n.StreamingControls.quickSettings, systemImage: "gearshape.2")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)
            .focused(focusedControl, equals: .quickSettingsHeader)

            if isExpanded {
                VStack(spacing: 16) {
                    // Bitrate Stepper
                    bitrateControl

                    Divider()
                        .padding(.vertical, 4)

                    // Volume Slider (duplicate for quick access)
                    volumeControl

                    Divider()
                        .padding(.vertical, 4)

                    // Resolution Picker
                    resolutionControl

                    // Reconnect Warning & Button
                    if pendingResolution != nil && pendingResolution != currentResolution {
                        reconnectWarning
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .onAppear {
            pendingResolution = currentResolution
        }
    }

    // MARK: - Bitrate Control

    private var bitrateControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(L10n.StreamingControls.bitrate, systemImage: "speedometer")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(QuickSettingsConfig.formatBitrate(bitrate))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
            }

            HStack(spacing: 12) {
                // Decrease button
                Button(action: {
                    HapticFeedback.selection()
                    bitrate = max(QuickSettingsConfig.minBitrate, bitrate - QuickSettingsConfig.bitrateStep)
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(bitrate > QuickSettingsConfig.minBitrate ? Color.chiakiPurple : Color.gray)
                }
                .buttonStyle(FocusableButtonStyle(cornerRadius: 20))
                .focused(focusedControl, equals: .bitrateDecrease)
                .disabled(bitrate <= QuickSettingsConfig.minBitrate)

                // Progress indicator
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.chiakiPurple)
                            .frame(width: bitrateProgress * geometry.size.width)
                    }
                }
                .frame(height: 8)

                // Increase button
                Button(action: {
                    HapticFeedback.selection()
                    bitrate = min(QuickSettingsConfig.maxBitrate, bitrate + QuickSettingsConfig.bitrateStep)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(bitrate < QuickSettingsConfig.maxBitrate ? Color.chiakiPurple : Color.gray)
                }
                .buttonStyle(FocusableButtonStyle(cornerRadius: 20))
                .focused(focusedControl, equals: .bitrateIncrease)
                .disabled(bitrate >= QuickSettingsConfig.maxBitrate)
            }
        }
    }

    private var bitrateProgress: CGFloat {
        let range = Double(QuickSettingsConfig.maxBitrate - QuickSettingsConfig.minBitrate)
        let current = Double(bitrate - QuickSettingsConfig.minBitrate)
        return CGFloat(current / range)
    }

    // MARK: - Volume Control

    private var volumeControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(L10n.StreamingControls.volume, systemImage: QuickSettingsConfig.volumeIcon(for: volume))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(volume * 100))%")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
            }

            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                TouchableSlider(value: $volume, range: 0...1, tint: .chiakiPurple)
                    .focused(focusedControl, equals: .quickSettingsVolume)

                Image(systemName: "speaker.wave.3.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }

    // MARK: - Resolution Control

    private var resolutionControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(L10n.StreamingControls.resolution, systemImage: "rectangle.on.rectangle")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                if pendingResolution != currentResolution {
                    Text(L10n.StreamingControls.requiresReconnect)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            #if os(tvOS)
            // tvOS: Horizontal buttons for focus navigation
            HStack(spacing: 12) {
                ForEach(QuickSettingsConfig.availableResolutions) { resolution in
                    Button(action: {
                        HapticFeedback.selection()
                        pendingResolution = resolution
                    }) {
                        Text(resolution.rawValue)
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(pendingResolution == resolution ? Color.chiakiPurple.opacity(0.3) : Color.clear)
                            .clipShape(.rect(cornerRadius: 8))
                    }
                    .buttonStyle(FocusableButtonStyle(cornerRadius: 8))
                    .focused(focusedControl, equals: .resolutionPicker)
                }
            }
            #else
            // iOS/macOS: Segmented picker
            Picker(selection: Binding(
                get: { pendingResolution ?? currentResolution },
                set: { pendingResolution = $0 }
            ), label: EmptyView()) {
                ForEach(QuickSettingsConfig.availableResolutions) { resolution in
                    Text(resolution.rawValue).tag(resolution)
                }
            }
            .pickerStyle(.segmented)
            .focused(focusedControl, equals: .resolutionPicker)
            #endif
        }
    }

    // MARK: - Reconnect Warning

    private var reconnectWarning: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(L10n.StreamingControls.resolutionChangeWarning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(action: {
                HapticFeedback.button()
                applyResolutionChange()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text(L10n.StreamingControls.applyAndReconnect)
                }
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(0.2))
                .foregroundStyle(.orange)
                .clipShape(.rect(cornerRadius: 8))
            }
            .buttonStyle(FocusableButtonStyle(cornerRadius: 8))
            .focused(focusedControl, equals: .reconnectButton)
        }
        .padding(.top, 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Actions

    private func applyResolutionChange() {
        guard let newResolution = pendingResolution, newResolution != currentResolution else { return }

        // Update settings
        settingsStore.streamSettings.localProfile.resolution = newResolution

        // Post notification to trigger reconnect
        NotificationCenter.default.post(name: .reconnectRequired, object: newResolution)
    }
}


// MARK: - Preview

#if DEBUG
#Preview {
    ZStack {
        Color.black

        VStack {
            QuickSettingsSection(
                volume: .constant(0.7),
                bitrate: .constant(15000),
                currentResolution: .r1080p,
                focusedControl: FocusState<StreamingControlFocus?>().projectedValue
            )
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(.rect(cornerRadius: 12))
        }
        .padding()
    }
    .environment(SettingsStore())
}
#endif
