import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: SettingsStore
    
    var body: some View {
        #if os(iOS)
        NavigationView {
            Form {
                Section {
                    NavigationLink(destination: VideoSettingsView()) {
                        Label("Video", systemImage: "display")
                    }
                    NavigationLink(destination: AudioSettingsView()) {
                        Label("Audio", systemImage: "speaker.wave.2")
                    }
                    NavigationLink(destination: ControllerSettingsView()) {
                        Label("Controller", systemImage: "gamecontroller")
                    }
                }
                
                Section {
                    NavigationLink(destination: Text("Account Settings Placeholder")) {
                        Label("Account", systemImage: "person.crop.circle")
                    }
                }
            }
            .navigationTitle("Settings")
        }
        #elseif os(macOS)
        TabView {
            VideoSettingsView()
                .tabItem {
                    Label("Video", systemImage: "display")
                }
            
            AudioSettingsView()
                .tabItem {
                    Label("Audio", systemImage: "speaker.wave.2")
                }
            
            ControllerSettingsView()
                .tabItem {
                    Label("Controller", systemImage: "gamecontroller")
                }
            
            Text("Account Settings Placeholder")
                .tabItem {
                    Label("Account", systemImage: "person.crop.circle")
                }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
        #endif
    }
}
