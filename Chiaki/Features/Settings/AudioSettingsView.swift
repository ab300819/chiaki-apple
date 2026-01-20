import SwiftUI

struct AudioSettingsView: View {
    @Environment(SettingsStore.self) var store

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Volume")
                        Spacer()
                        Text("\(Int(store.streamSettings.volume * 100))%")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $store.streamSettings.volume, in: 0...1) {
                        Text("Volume")
                    }
                }
                
                Toggle("Microphone", isOn: $store.streamSettings.microphoneEnabled)
            } header: {
                Text("Output & Input")
            }
            
            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Buffer Size")
                        Spacer()
                        Text("\(store.streamSettings.audioBufferSize) ms")
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(store.streamSettings.audioBufferSize) },
                            set: { store.streamSettings.audioBufferSize = Int($0) }
                        ),
                        in: 10...100,
                        step: 5
                    )
                }
            } header: {
                Text("Advanced")
            }
        }
        .navigationTitle("Audio")
        #if os(macOS)
        .formStyle(.grouped)
        #endif
    }
}

#Preview {
    NavigationStack {
        AudioSettingsView()
            .environment(SettingsStore())
            .environment(NavigationManager())
    }
}
