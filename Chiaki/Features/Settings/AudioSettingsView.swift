import SwiftUI

struct AudioSettingsView: View {
    @Environment(SettingsStore.self) var store

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text(L10n.Settings.Audio.volume)
                        Spacer()
                        Text(String(localized: "settings.audio.percent \(Int(store.streamSettings.volume * 100))"))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $store.streamSettings.volume, in: 0...1) {
                        Text(L10n.Settings.Audio.volume)
                    }
                }

                Toggle(L10n.Settings.Audio.microphone, isOn: $store.streamSettings.microphoneEnabled)
            } header: {
                Text(L10n.Settings.Audio.outputInput)
            }

            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text(String(localized: "settings.audio.bufferSize"))
                        Spacer()
                        Text(String(localized: "settings.audio.ms \(store.streamSettings.audioBufferSize)"))
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
                Text(L10n.Settings.Video.advanced)
            }
        }
        .navigationTitle(L10n.Nav.audio)
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
