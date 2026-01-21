//
//  ContentView.swift
//  Chiaki
//
//  Main content view with navigation structure
//

import SwiftUI

struct ContentView: View {
    @Environment(NavigationManager.self) var navigationManager
    @Environment(SettingsStore.self) var settingsStore
    @Environment(HostStore.self) var hostStore

    @State private var hasCheckedAutoConnect = false
    @State private var autoConnectTargetHost: ConsoleHost?

    var body: some View {
        Group {
            if navigationManager.isAutoConnecting, let host = navigationManager.autoConnectHost {
                autoConnectView(for: host)
            } else {
                mainContentView
            }
        }
        .task {
            await checkAutoConnect()
        }
    }

    @ViewBuilder
    private var mainContentView: some View {
        #if os(macOS)
        @Bindable var manager = navigationManager
        NavigationSplitView {
            List(selection: $manager.sidebarSelection) {
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

    @ViewBuilder
    private func autoConnectView(for host: ConsoleHost) -> some View {
        AutoConnectView(
            host: host,
            onConnected: {
                // Navigate to streaming view
                autoConnectTargetHost = host
                navigationManager.endAutoConnect()
            },
            onCancelled: {
                navigationManager.endAutoConnect()
            }
        )
        #if os(macOS)
        .sheet(item: $autoConnectTargetHost) { host in
            StreamingView(host: host)
                .frame(minWidth: 800, minHeight: 600)
        }
        #else
        .fullScreenCover(item: $autoConnectTargetHost) { host in
            StreamingView(host: host)
        }
        #endif
    }

    private func checkAutoConnect() async {
        guard !hasCheckedAutoConnect else { return }
        hasCheckedAutoConnect = true

        // Check if auto-connect is enabled
        guard settingsStore.autoConnectEnabled else { return }

        // Find the target host
        let targetHost: ConsoleHost?
        if let hostId = settingsStore.autoConnectHostId {
            targetHost = hostStore.host(byId: hostId)
        } else {
            // Use the last connected host
            targetHost = hostStore.hosts
                .filter { $0.isRegistered }
                .sorted { ($0.lastConnectedAt ?? .distantPast) > ($1.lastConnectedAt ?? .distantPast) }
                .first
        }

        guard let host = targetHost, host.isRegistered else { return }

        // Start auto-connect
        navigationManager.startAutoConnect(host: host)
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
