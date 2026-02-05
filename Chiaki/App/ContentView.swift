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
        @Bindable var manager = navigationManager
        TabView(selection: $manager.selectedTab) {
            /**
             * Main host list tab
             * @requirement F-033
             * @satisfies AC-116
             */
            NavigationStack {
                HostListView()
            }
            .tabItem {
                Label("Hosts", systemImage: "gamecontroller")
            }
            .tag(AppTab.hosts)

            /**
             * App settings tab
             * @requirement F-033
             * @satisfies AC-116
             */
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(AppTab.settings)
        }
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

#Preview {
    ContentView()
        .environment(SettingsStore())
        .environment(NavigationManager())
        .environment(HostStore())
}
