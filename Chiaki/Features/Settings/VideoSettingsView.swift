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
