import SwiftUI

struct ControllerSettingsView: View {
    @Environment(SettingsStore.self) var store

    let connectedControllers = [
        "DualSense Wireless Controller",
        "Xbox Wireless Controller"
    ]
    
    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                Toggle("Haptic Feedback", isOn: $store.streamSettings.hapticFeedbackEnabled)
            } header: {
                Text("Preferences")
            }
            
            Section {
                if connectedControllers.isEmpty {
                    Text("No controllers connected")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(connectedControllers, id: \.self) { controller in
                        HStack {
                            Image(systemName: "gamecontroller")
                            Text(controller)
                        }
                    }
                }
            } header: {
                Text("Connected Controllers")
            }
        }
        .navigationTitle("Controller")
        #if os(macOS)
        .formStyle(.grouped)
        #endif
    }
}

#Preview {
    NavigationStack {
        ControllerSettingsView()
            .environment(SettingsStore())
            .environment(NavigationManager())
    }
}
