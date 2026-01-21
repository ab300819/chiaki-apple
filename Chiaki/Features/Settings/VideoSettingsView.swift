import SwiftUI

struct VideoSettingsView: View {
    @Environment(SettingsStore.self) var store

    // HDR mode helpers
    private enum HDRPeakMode {
        case auto, manual
    }

    private enum HDRContrastMode {
        case auto, infinity, manual
    }

    private var hdrPeakModeBinding: Binding<HDRPeakMode> {
        Binding(
            get: { store.streamSettings.hdrTargetPeakNits == 0 ? .auto : .manual },
            set: { mode in
                if mode == .auto {
                    store.streamSettings.hdrTargetPeakNits = 0
                } else {
                    store.streamSettings.hdrTargetPeakNits = 1000 // Default to 1000 nits
                }
            }
        )
    }

    private var hdrPeakNitsBinding: Binding<Double> {
        Binding(
            get: { Double(store.streamSettings.hdrTargetPeakNits) },
            set: { store.streamSettings.hdrTargetPeakNits = Int($0) }
        )
    }

    private var hdrContrastModeBinding: Binding<HDRContrastMode> {
        Binding(
            get: {
                switch store.streamSettings.hdrTargetContrast {
                case 0: return .auto
                case -1: return .infinity
                default: return .manual
                }
            },
            set: { mode in
                switch mode {
                case .auto: store.streamSettings.hdrTargetContrast = 0
                case .infinity: store.streamSettings.hdrTargetContrast = -1
                case .manual: store.streamSettings.hdrTargetContrast = 1000 // Default
                }
            }
        )
    }

    private var hdrContrastBinding: Binding<Double> {
        Binding(
            get: { Double(max(1000, store.streamSettings.hdrTargetContrast)) },
            set: { store.streamSettings.hdrTargetContrast = Int($0) }
        )
    }

    private func formatContrast(_ value: Int) -> String {
        if value >= 1000000 {
            return String(format: "%.1fM:1", Double(value) / 1_000_000)
        } else if value >= 1000 {
            return String(format: "%.0fK:1", Double(value) / 1000)
        } else {
            return "\(value):1"
        }
    }

    var body: some View {
        @Bindable var store = store
        
        Form {
            Section {
                Picker(L10n.Settings.Video.profile, selection: $store.useRemoteProfile) {
                    Text(L10n.Settings.Video.local).tag(false)
                    Text(L10n.Settings.Video.remote).tag(true)
                }
                .pickerStyle(.segmented)

                let currentProfile = store.useRemoteProfile ? $store.streamSettings.remoteProfile : $store.streamSettings.localProfile

                Picker(L10n.Settings.Video.resolution, selection: currentProfile.resolution) {
                    ForEach(StreamSettings.Resolution.allCases) { resolution in
                        Text(resolution.rawValue).tag(resolution)
                    }
                }

                Picker(L10n.Settings.Video.frameRate, selection: currentProfile.frameRate) {
                    ForEach(StreamSettings.FrameRate.allCases) { fps in
                        Text(String(localized: "settings.video.fps \(fps.rawValue)")).tag(fps)
                    }
                }

                VStack(alignment: .leading) {
                    HStack {
                        Text(L10n.Settings.Video.bitrate)
                        Spacer()
                        Text(String(localized: "settings.video.mbps \(Int(currentProfile.wrappedValue.bitrate / 1000))"))
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(currentProfile.wrappedValue.bitrate) },
                            set: { currentProfile.wrappedValue.bitrate = Int($0) }
                        ),
                        in: 5000...100000,
                        step: 1000
                    ) {
                        Text(L10n.Settings.Video.bitrate)
                    }
                }

                Toggle(L10n.Settings.Video.hdr, isOn: $store.streamSettings.hdrEnabled)
            } header: {
                Text(L10n.Settings.Video.quality)
            }

            // HDR Fine-tuning Section (only shown when HDR is enabled)
            if store.streamSettings.hdrEnabled {
                Section {
                    // Target Peak Nits
                    Picker(String(localized: "settings.video.targetPeak"), selection: hdrPeakModeBinding) {
                        Text(String(localized: "settings.video.auto")).tag(HDRPeakMode.auto)
                        Text(String(localized: "settings.video.manual")).tag(HDRPeakMode.manual)
                    }

                    if store.streamSettings.hdrTargetPeakNits > 0 {
                        VStack(alignment: .leading) {
                            HStack {
                                Text(String(localized: "settings.video.peakBrightness"))
                                Spacer()
                                Text(String(localized: "settings.video.nits \(store.streamSettings.hdrTargetPeakNits)"))
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(
                                value: hdrPeakNitsBinding,
                                in: 100...10000,
                                step: 100
                            )
                        }
                    }

                    // Target Contrast
                    Picker(String(localized: "settings.video.targetContrast"), selection: hdrContrastModeBinding) {
                        Text(String(localized: "settings.video.auto")).tag(HDRContrastMode.auto)
                        Text(String(localized: "settings.video.infinity")).tag(HDRContrastMode.infinity)
                        Text(String(localized: "settings.video.manual")).tag(HDRContrastMode.manual)
                    }

                    if store.streamSettings.hdrTargetContrast > 0 {
                        VStack(alignment: .leading) {
                            HStack {
                                Text(String(localized: "settings.video.contrastRatio"))
                                Spacer()
                                Text(formatContrast(store.streamSettings.hdrTargetContrast))
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(
                                value: hdrContrastBinding,
                                in: 1000...100000,
                                step: 1000
                            )
                        }
                    }
                } header: {
                    Text(L10n.Settings.Video.hdrFineTuning)
                } footer: {
                    Text(L10n.Settings.Video.hdrDescription)
                }
            }

            Section {
                Toggle(String(localized: "settings.video.hardwareDecoding"), isOn: $store.streamSettings.hardwareDecodingEnabled)

                Picker(String(localized: "settings.video.colorSpace"), selection: $store.streamSettings.colorSpace) {
                    ForEach(StreamSettings.ColorSpace.allCases) { colorSpace in
                        Text(colorSpace.rawValue).tag(colorSpace)
                    }
                }
            } header: {
                Text(L10n.Settings.Video.advanced)
            }

            Section {
                Picker(L10n.StreamingControls.displayMode, selection: $store.streamSettings.displayMode) {
                    ForEach(StreamSettings.DisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

                if store.streamSettings.displayMode == .zoom {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(L10n.StreamingControls.zoomLevel)
                            Spacer()
                            Text(String(format: "%.1fx", store.streamSettings.zoomFactor))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $store.streamSettings.zoomFactor, in: 1.0...2.0, step: 0.1)
                    }
                }
            } header: {
                Text(L10n.Settings.Video.scaling)
            }
        }
        .navigationTitle(L10n.Nav.video)
        #if os(macOS)
        .formStyle(.grouped)
        #endif
    }
}

#Preview {
    NavigationStack {
        VideoSettingsView()
            .environment(SettingsStore())
            .environment(NavigationManager())
    }
}
