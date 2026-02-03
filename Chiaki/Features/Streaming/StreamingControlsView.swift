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
    var onToggleMic: (() -> Void)?

    /**
     * Focus state management for controller navigation
     * @satisfies AC-055 - 流媒体控制菜单焦点管理
     */
    @FocusState private var focusedControl: StreamingControlFocus?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(L10n.Streaming.controls)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                // Controller battery indicator
                // @satisfies AC-064 - 控制器电池电量显示
                ControllerBatteryIndicator(
                    batteryInfo: ControllerManager.shared.batteryInfo,
                    compact: true
                )

                Button(action: {
                    HapticFeedback.button()
                    viewModel.toggleControlMenu()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(FocusableButtonStyle(cornerRadius: 20))
                .focused($focusedControl, equals: .closeButton)
            }
            .padding()
            .background(Color(white: 0.15))

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // Volume & Mic Control
                    AudioControlSection(
                        volume: Binding(
                            get: { viewModel.volume },
                            set: { 
                                if $0 != viewModel.volume {
                                    HapticFeedback.selection()
                                }
                                viewModel.setVolume($0) 
                            }
                        ),
                        isMicEnabled: viewModel.isMicEnabled,
                        isMicMuted: viewModel.isMicMuted,
                        onToggleMic: onToggleMic,
                        focusedControl: $focusedControl
                    )

                    Divider()

                    // Display Mode Control
                    DisplayModeSection(
                        displayMode: Binding(
                            get: { viewModel.displayMode },
                            set: { 
                                HapticFeedback.selection()
                                viewModel.setDisplayMode($0) 
                            }
                        ),
                        zoomFactor: Binding(
                            get: { viewModel.zoomFactor },
                            set: { 
                                if $0 != viewModel.zoomFactor {
                                    HapticFeedback.selection()
                                }
                                viewModel.setZoomFactor($0) 
                            }
                        ),
                        focusedControl: $focusedControl
                    )

                    Divider()

                    // Video Preset Control
                    VideoPresetSection(
                        preset: Binding(
                            get: { viewModel.videoPreset },
                            set: { 
                                HapticFeedback.selection()
                                viewModel.setVideoPreset($0) 
                            }
                        ),
                        focusedControl: $focusedControl
                    )

                    Divider()

                    // Quick Actions
                    QuickActionsSection(
                        isOverlayVisible: Binding(
                            get: { viewModel.isOverlayVisible },
                            set: { _ in viewModel.toggleOverlay() }
                        ),
                        onDisconnect: onDisconnect,
                        onGoToBed: onGoToBed,
                        focusedControl: $focusedControl
                    )
                }
                .padding()
            }
        }
        .frame(width: controlsWidth, height: controlsHeight)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .onAppear {
            /**
             * Focus restoration on menu appear
             * @requirement F-020 - 手柄操作友好化
             * @satisfies AC-060 - 焦点恢复逻辑
             */
            // Restore previous focus if available, otherwise default to disconnectButton
            focusedControl = viewModel.lastControlMenuFocus ?? .disconnectButton
        }
        .onDisappear {
            /**
             * Save focus state before menu closes
             * @satisfies AC-060 - 焦点恢复逻辑
             */
            viewModel.lastControlMenuFocus = focusedControl
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

// MARK: - Audio Control Section

private struct AudioControlSection: View {
    @Binding var volume: Double
    let isMicEnabled: Bool
    let isMicMuted: Bool
    var onToggleMic: (() -> Void)?
    var focusedControl: FocusState<StreamingControlFocus?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.StreamingControls.audio, systemImage: volumeIcon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                TouchableSlider(value: $volume, range: 0...1, tint: .chiakiPurple)
                    .focused(focusedControl, equals: .volumeSlider)

                Image(systemName: "speaker.wave.3.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                Text("\(Int(volume * 100))%")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }

            // Microphone toggle (if enabled)
            if isMicEnabled, let toggleMic = onToggleMic {
                HStack {
                    Button(action: toggleMic) {
                        HStack(spacing: 8) {
                            Image(systemName: isMicMuted ? "mic.slash.fill" : "mic.fill")
                                .foregroundStyle(isMicMuted ? .red : .green)
                            Text(isMicMuted ? L10n.StreamingControls.micMuted : L10n.StreamingControls.micActive)
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isMicMuted ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
                        .clipShape(.rect(cornerRadius: 8))
                    }
                    .buttonStyle(FocusableButtonStyle(cornerRadius: 8))
                    .focused(focusedControl, equals: .micToggle)

                    Spacer()
                }
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
    var focusedControl: FocusState<StreamingControlFocus?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.StreamingControls.displayMode, systemImage: "rectangle.on.rectangle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

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
                        .background(displayMode == mode ? Color.chiakiPurple.opacity(0.3) : Color.clear)
                        .clipShape(.rect(cornerRadius: 8))
                    }
                    .buttonStyle(FocusableButtonStyle(cornerRadius: 8))
                    .focused(focusedControl, equals: .displayModePicker)
                }
            }
            #else
            // iOS/macOS: Segmented picker
            Picker( selection: $displayMode,label:EmptyView()) {
                ForEach(StreamSettings.DisplayMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.iconName)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .focused(focusedControl, equals: .displayModePicker)
            #endif

            // Zoom factor slider (only shown in zoom mode)
            if displayMode == .zoom {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.StreamingControls.zoomLevel)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Image(systemName: "minus.magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.caption)

                        TouchableSlider(value: $zoomFactor, range: 1.0...2.0, tint: .chiakiPurple)
                            .focused(focusedControl, equals: .zoomSlider) 

                        Image(systemName: "plus.magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.caption)

                        Text(String(format: "%.1fx", zoomFactor))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity,alignment: .leading)
        .animation(.easeInOut(duration: 0.2), value: displayMode)
    }
}

// MARK: - Video Preset Section

private struct VideoPresetSection: View {
    @Binding var preset: StreamSettings.VideoPreset
    var focusedControl: FocusState<StreamingControlFocus?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.StreamingControls.videoPreset, systemImage: "sparkles.rectangle.stack")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            #if os(tvOS)
            // tvOS: Horizontal buttons for focus navigation
            HStack(spacing: 12) {
                ForEach(StreamSettings.VideoPreset.allCases) { presetOption in
                    Button(action: { preset = presetOption }) {
                        VStack(spacing: 8) {
                            Image(systemName: presetOption.iconName)
                                .font(.title2)
                            Text(presetOption.rawValue)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(preset == presetOption ? Color.chiakiPurple.opacity(0.3) : Color.clear)
                        .clipShape(.rect(cornerRadius: 8))
                    }
                    .buttonStyle(FocusableButtonStyle(cornerRadius: 8))
                    .focused(focusedControl, equals: .qualityPicker)
                }
            }
            #else
            // iOS/macOS: Segmented picker
            Picker(selection: $preset,label:EmptyView()) {
                ForEach(StreamSettings.VideoPreset.allCases) { presetOption in
                    Label(presetOption.rawValue, systemImage: presetOption.iconName)
                        .tag(presetOption)
                }
            }
            .pickerStyle(.segmented)
            .focused(focusedControl, equals: .qualityPicker)

            // Description
            Text(preset.description)
                .font(.caption)
                .foregroundStyle(.secondary)
            #endif
        }
    }
}

// MARK: - Quick Actions Section

/**
 * Quick action buttons with Apple HIG compliant touch spacing
 * @requirement F-023 - iPad 触摸操作友好化
 * @satisfies AC-070 - 控件间距优化
 */
private struct QuickActionsSection: View {
    @Binding var isOverlayVisible: Bool
    var onDisconnect: () -> Void
    var onGoToBed: () -> Void
    var focusedControl: FocusState<StreamingControlFocus?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.StreamingControls.quickActions, systemImage: "bolt.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: ChiakiTheme.Touch.minSpacing) {
                // Show/Hide stats overlay
                Button(action: { 
                    HapticFeedback.button()
                    isOverlayVisible.toggle() 
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: isOverlayVisible ? "chart.bar.xaxis" : "chart.bar")
                            .font(.title2)
                            .foregroundStyle(.blue)

                        Text(L10n.StreamingControls.toggleStats)
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.15))
                    .clipShape(.rect(cornerRadius: 10))
                }
                .buttonStyle(FocusableButtonStyle(cornerRadius: 10))
                .focused(focusedControl, equals: .statsToggle)

                // Go to Bed (Rest Mode)
                ActionButton(
                    title: L10n.Streaming.restMode,
                    icon: "moon.fill",
                    color: .orange,
                    action: onGoToBed
                )
                .focused(focusedControl, equals: .restModeButton)

                // Disconnect
                ActionButton(
                    title: L10n.Streaming.disconnect,
                    icon: "xmark.circle.fill",
                    color: .red,
                    action: onDisconnect
                )
                .focused(focusedControl, equals: .disconnectButton)
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
        Button(action: {
            HapticFeedback.button()
            action()
        }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.15))
            .clipShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(FocusableButtonStyle(cornerRadius: 10))
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

/**
 * Focusable controls in the streaming control menu
 * @requirement F-020 - 手柄操作友好化
 * @satisfies AC-055 - 流媒体控制菜单焦点管理
 */
enum StreamingControlFocus: String, Hashable, CaseIterable {
    /// Button to disconnect from the host
    case disconnectButton
    
    /// Toggle for microphone mute state
    case micToggle
    
    /// Slider for audio volume
    case volumeSlider
    
    /// Slider for zoom factor
    case zoomSlider
    
    /// Picker for video quality/preset
    case qualityPicker
    
    /// Picker for display mode (Fit/Stretch/Zoom)
    case displayModePicker
    
    /// Toggle for streaming statistics overlay
    case statsToggle
    
    /// Button to close the control menu
    case closeButton
    
    /// Button for rest mode
    case restModeButton
}
