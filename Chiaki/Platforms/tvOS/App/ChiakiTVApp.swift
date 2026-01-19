//
//  ChiakiTVApp.swift
//  ChiakiTV
//
//  PlayStation Remote Play client for tvOS
//

import SwiftUI

#if os(tvOS)
@main
struct ChiakiTVApp: App {
    @State private var settingsStore = SettingsStore()
    @State private var navigationManager = NavigationManager()

    var body: some Scene {
        WindowGroup {
            TVContentView()
                .environment(settingsStore)
                .environment(navigationManager)
        }
    }
}
#endif

struct TVContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                HostListView()
            }
            .tabItem {
                Label("Hosts", systemImage: "gamecontroller")
            }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    TVContentView()
        .environment(SettingsStore())
        .environment(NavigationManager())
}
