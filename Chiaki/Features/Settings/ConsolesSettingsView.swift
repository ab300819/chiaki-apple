import SwiftUI

struct ConsolesSettingsView: View {
    @Environment(HostStore.self) var hostStore
    @Environment(SettingsStore.self) var settingsStore

    @State private var showDeleteConfirmation = false
    @State private var showHideConfirmation = false
    @State private var showUnhideConfirmation = false
    @State private var selectedHost: ConsoleHost?

    var body: some View {
        Form {
            // Registered Consoles Section
            Section {
                if hostStore.registeredHosts.isEmpty {
                    Text("No registered consoles")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(hostStore.registeredHosts) { host in
                        RegisteredHostRow(
                            host: host,
                            streamerMode: settingsStore.streamerModeEnabled,
                            onDelete: {
                                selectedHost = host
                                showDeleteConfirmation = true
                            },
                            onHide: {
                                selectedHost = host
                                showHideConfirmation = true
                            }
                        )
                    }
                }
            } header: {
                Text("Registered Consoles")
            } footer: {
                Text("Manage your registered PlayStation consoles. Hidden consoles won't appear in the host list.")
            }

            // Hidden Consoles Section
            if !hostStore.hiddenHosts.isEmpty {
                Section {
                    ForEach(hostStore.hiddenHosts) { host in
                        HiddenHostRow(
                            host: host,
                            streamerMode: settingsStore.streamerModeEnabled,
                            onUnhide: {
                                selectedHost = host
                                showUnhideConfirmation = true
                            }
                        )
                    }
                } header: {
                    Text("Hidden Consoles")
                } footer: {
                    Text("These consoles are hidden from the main host list but remain registered.")
                }
            }
        }
        .navigationTitle("Consoles")
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .confirmationDialog(
            "Delete Console",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let host = selectedHost {
                    hostStore.removeHost(host)
                }
                selectedHost = nil
            }
            Button("Cancel", role: .cancel) {
                selectedHost = nil
            }
        } message: {
            if let host = selectedHost {
                Text("Are you sure you want to delete \"\(host.nickname)\"? This will remove its registration and you'll need to re-register to connect.")
            }
        }
        .confirmationDialog(
            "Hide Console",
            isPresented: $showHideConfirmation,
            titleVisibility: .visible
        ) {
            Button("Hide") {
                if let host = selectedHost {
                    hostStore.hideHost(host)
                }
                selectedHost = nil
            }
            Button("Cancel", role: .cancel) {
                selectedHost = nil
            }
        } message: {
            if let host = selectedHost {
                Text("Are you sure you want to hide \"\(host.nickname)\"? It will no longer appear in the host list but will remain registered.")
            }
        }
        .confirmationDialog(
            "Unhide Console",
            isPresented: $showUnhideConfirmation,
            titleVisibility: .visible
        ) {
            Button("Unhide") {
                if let host = selectedHost {
                    hostStore.unhideHost(host)
                }
                selectedHost = nil
            }
            Button("Cancel", role: .cancel) {
                selectedHost = nil
            }
        } message: {
            if let host = selectedHost {
                Text("Are you sure you want to unhide \"\(host.nickname)\"? It will appear in the host list again.")
            }
        }
    }
}

// MARK: - Registered Host Row

private struct RegisteredHostRow: View {
    let host: ConsoleHost
    let streamerMode: Bool
    let onDelete: () -> Void
    let onHide: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: host.isPS5 ? "playstation.logo" : "gamecontroller.fill")
                        .foregroundStyle(host.isPS5 ? .blue : .indigo)

                    Text(host.nickname)
                        .font(.headline)

                    if host.isHidden {
                        Text("Hidden")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }

                Text(hostInfoText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            #if os(iOS)
            Menu {
                Button(action: onHide) {
                    Label("Hide", systemImage: "eye.slash")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            #else
            HStack(spacing: 12) {
                Button("Hide", action: onHide)
                    .buttonStyle(.bordered)

                Button("Delete", role: .destructive, action: onDelete)
                    .buttonStyle(.bordered)
            }
            #endif
        }
        .padding(.vertical, 4)
    }

    private var hostInfoText: String {
        let consoleType = host.isPS5 ? "PS5" : "PS4"
        let macDisplay = streamerMode ? "XX:XX:XX:XX:XX:XX" : host.macAddress
        return "\(consoleType) • \(macDisplay)"
    }
}

// MARK: - Hidden Host Row

private struct HiddenHostRow: View {
    let host: ConsoleHost
    let streamerMode: Bool
    let onUnhide: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: host.isPS5 ? "playstation.logo" : "gamecontroller.fill")
                        .foregroundStyle(.secondary)

                    Text(host.nickname)
                        .font(.headline)
                }

                Text(hostInfoText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Unhide", action: onUnhide)
                .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }

    private var hostInfoText: String {
        let consoleType = host.isPS5 ? "PS5" : "PS4"
        let macDisplay = streamerMode ? "XX:XX:XX:XX:XX:XX" : host.macAddress
        return "\(consoleType) • \(macDisplay)"
    }
}

#Preview {
    NavigationStack {
        ConsolesSettingsView()
            .environment(HostStore())
            .environment(SettingsStore())
    }
}
