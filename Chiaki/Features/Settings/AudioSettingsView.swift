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
