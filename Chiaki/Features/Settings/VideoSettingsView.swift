import SwiftUI

struct VideoSettingsView: View {
    @Environment(SettingsStore.self) var store

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                Picker("Resolution", selection: $store.streamSettings.resolution) {
                    ForEach(StreamSettings.Resolution.allCases) { resolution in
                        Text(resolution.rawValue).tag(resolution)
                    }
                }
                
                Picker("Frame Rate", selection: $store.streamSettings.frameRate) {
                    ForEach(StreamSettings.FrameRate.allCases) { fps in
                        Text("\(fps.rawValue) FPS").tag(fps)
                    }
                }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Bitrate")
                        Spacer()
                        Text("\(Int(store.streamSettings.bitrate / 1000)) Mbps")
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(store.streamSettings.bitrate) },
                            set: { store.streamSettings.bitrate = Int($0) }
                        ),
                        in: 5000...50000,
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
