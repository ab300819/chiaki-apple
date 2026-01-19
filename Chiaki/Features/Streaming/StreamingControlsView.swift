// SPDX-License-Identifier: AGPL-3.0-only
//
// StreamingControlsView.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Floating control menu for streaming session

import SwiftUI

/// Floating control menu for streaming playback settings
struct StreamingControlsView: View {
    @Bindable var viewModel: StreamingViewModel
    var onSaveSettings: (Double, StreamSettings.DisplayMode, Double) -> Void
    var onDisconnect: () -> Void
    var onGoToBed: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Controls")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: { viewModel.toggleControlMenu() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(white: 0.15))

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // Volume Control
                    VolumeControlSection(
                        volume: Binding(
                            get: { viewModel.volume },
                            set: { viewModel.setVolume($0) }
                        )
                    )

                    Divider()

                    // Display Mode Control
                    DisplayModeSection(
                        displayMode: Binding(
                            get: { viewModel.displayMode },
                            set: { viewModel.setDisplayMode($0) }
                        ),
                        zoomFactor: Binding(
                            get: { viewModel.zoomFactor },
                            set: { viewModel.setZoomFactor($0) }
                        )
                    )

                    Divider()

                    // Quick Actions
                    QuickActionsSection(
                        onDisconnect: onDisconnect,
                        onGoToBed: onGoToBed
                    )
                }
                .padding()
            }
        }
        .frame(width: controlsWidth, height: controlsHeight)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .onDisappear {
            // Save settings when menu closes
            onSaveSettings(viewModel.volume, viewModel.displayMode, viewModel.zoomFactor)
        }
    }

    #if os(tvOS)
    private let controlsWidth: CGFloat = 500
    private let controlsHeight: CGFloat = 450
    #else
    private let controlsWidth: CGFloat = 320
    private let controlsHeight: CGFloat = 380
    #endif
}

// MARK: - Volume Control Section

private struct VolumeControlSection: View {
    @Binding var volume: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Volume", systemImage: volumeIcon)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                    .foregroundColor(.secondary)
                    .font(.caption)

                Slider(value: $volume, in: 0...1)
                    .tint(.blue)

                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(.secondary)
                    .font(.caption)

                Text("\(Int(volume * 100))%")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }

    private var volumeIcon: String {
        if volume == 0 {
            return "speaker.slash.fill"
        } else if volume < 0.33 {
            return "speaker.fill"
        } else if volume < 0.66 {
            return "speaker.wave.1.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
}

// MARK: - Display Mode Section

private struct DisplayModeSection: View {
    @Binding var displayMode: StreamSettings.DisplayMode
    @Binding var zoomFactor: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Display Mode", systemImage: "rectangle.on.rectangle")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            #if os(tvOS)
            // tvOS: Horizontal buttons for focus navigation
            HStack(spacing: 12) {
                ForEach(StreamSettings.DisplayMode.allCases) { mode in
                    Button(action: { displayMode = mode }) {
                        VStack(spacing: 8) {
                            Image(systemName: mode.iconName)
                                .font(.title2)
                            Text(mode.rawValue)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(displayMode == mode ? Color.blue.opacity(0.3) : Color.clear)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            #else
            // iOS/macOS: Segmented picker
            Picker("Display Mode", selection: $displayMode) {
                ForEach(StreamSettings.DisplayMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.iconName)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            #endif

            // Zoom factor slider (only shown in zoom mode)
            if displayMode == .zoom {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Zoom Level")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Image(systemName: "minus.magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.caption)

                        Slider(value: $zoomFactor, in: 1.0...2.0)
                            .tint(.blue)

                        Image(systemName: "plus.magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.caption)

                        Text(String(format: "%.1fx", zoomFactor))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: displayMode)
    }
}

// MARK: - Quick Actions Section

private struct QuickActionsSection: View {
    var onDisconnect: () -> Void
    var onGoToBed: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quick Actions", systemImage: "bolt.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                // Go to Bed (Rest Mode)
                ActionButton(
                    title: "Rest Mode",
                    icon: "moon.fill",
                    color: .orange,
                    action: onGoToBed
                )

                // Disconnect
                ActionButton(
                    title: "Disconnect",
                    icon: "xmark.circle.fill",
                    color: .red,
                    action: onDisconnect
                )
            }
        }
    }
}

private struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.15))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black

        StreamingControlsView(
            viewModel: StreamingViewModel(host: MockData.hostPS5),
            onSaveSettings: { _, _, _ in },
            onDisconnect: {},
            onGoToBed: {}
        )
    }
    .environment(SettingsStore())
}
