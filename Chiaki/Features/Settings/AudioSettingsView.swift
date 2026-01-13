import SwiftUI

struct AudioSettingsView: View {
    @EnvironmentObject var store: SettingsStore
    
    var body: some View {
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
