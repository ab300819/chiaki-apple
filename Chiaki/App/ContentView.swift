//
//  ContentView.swift
//  Chiaki
//
//  Main content view with navigation structure
//

import SwiftUI

struct ContentView: View {
    @Environment(NavigationManager.self) var navigationManager
    
    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            List(selection: $navigationManager.sidebarSelection) {
                NavigationLink(value: SidebarItem.hosts) {
                    Label("Hosts", systemImage: "gamecontroller")
                }
                NavigationLink(value: SidebarItem.settings) {
                    Label("Settings", systemImage: "gear")
                }
            }
            .navigationTitle("Chiaki")
        } detail: {
            NavigationStack {
                switch navigationManager.sidebarSelection {
                case .hosts:
                    HostListView()
                case .settings:
                    SettingsView()
                case nil:
                    WelcomeView()
                }
            }
        }
        #else
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
        #endif
    }
}

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("Chiaki")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("PlayStation Remote Play")
                .foregroundStyle(.secondary)
            Text("Select a host to start streaming")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    ContentView()
        .environment(SettingsStore())
        .environment(NavigationManager())
}
