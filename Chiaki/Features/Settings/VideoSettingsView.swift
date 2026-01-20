import SwiftUI

struct VideoSettingsView: View {
    @Environment(SettingsStore.self) var store

    var body: some View {
        @Bindable var store = store
        
        Form {
            Section {
                Picker("Profile", selection: $store.useRemoteProfile) {
                    Text("Local").tag(false)
                    Text("Remote").tag(true)
                }
                .pickerStyle(.segmented)
                
                let currentProfile = store.useRemoteProfile ? $store.streamSettings.remoteProfile : $store.streamSettings.localProfile
                
                Picker("Resolution", selection: currentProfile.resolution) {
                    ForEach(StreamSettings.Resolution.allCases) { resolution in
                        Text(resolution.rawValue).tag(resolution)
                    }
                }
                
                Picker("Frame Rate", selection: currentProfile.frameRate) {
                    ForEach(StreamSettings.FrameRate.allCases) { fps in
                        Text("\(fps.rawValue) FPS").tag(fps)
                    }
                }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Bitrate")
                        Spacer()
                        Text("\(Int(currentProfile.wrappedValue.bitrate / 1000)) Mbps")
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
                        Text("Bitrate")
                    }
                }
                
                Toggle("HDR", isOn: $store.streamSettings.hdrEnabled)
            } header: {
                Text("Quality")
            }

            Section {
                Toggle("Hardware Decoding", isOn: $store.streamSettings.hardwareDecodingEnabled)
                
                Picker("Color Space", selection: $store.streamSettings.colorSpace) {
                    ForEach(StreamSettings.ColorSpace.allCases) { colorSpace in
                        Text(colorSpace.rawValue).tag(colorSpace)
                    }
                }
            } header: {
                Text("Advanced")
            }
            
            Section {
                Picker("Display Mode", selection: $store.streamSettings.displayMode) {
                    ForEach(StreamSettings.DisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                
                if store.streamSettings.displayMode == .zoom {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Zoom Level")
                            Spacer()
                            Text(String(format: "%.1fx", store.streamSettings.zoomFactor))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $store.streamSettings.zoomFactor, in: 1.0...2.0, step: 0.1)
                    }
                }
            } header: {
                Text("Scaling")
            }
        }
        .navigationTitle("Video")
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
