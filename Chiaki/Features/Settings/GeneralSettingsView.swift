import SwiftUI

struct GeneralSettingsView: View {
    @Environment(SettingsStore.self) var store
    @Environment(HostStore.self) var hostStore

    var body: some View {
        @Bindable var store = store
        Form {
            // Auto-Connect Section
            Section {
                Toggle(L10n.Settings.General.autoConnectOnLaunch, isOn: $store.autoConnectEnabled)

                if store.autoConnectEnabled {
                    Picker(L10n.Settings.General.targetConsole, selection: autoConnectHostBinding) {
                        Text(L10n.Settings.General.lastConnected).tag(nil as UUID?)
                        ForEach(registeredHosts) { host in
                            Text(host.nickname).tag(host.id as UUID?)
                        }
                    }

                    Toggle(L10n.Settings.General.wakeConsole, isOn: $store.autoConnectWakeUp)
                }
            } header: {
                Text(L10n.Settings.General.autoConnect)
            } footer: {
                Text(L10n.Settings.General.autoConnectDescription)
            }

            // Disconnect Action Section
            Section {
                Picker(L10n.Settings.General.onDisconnect, selection: $store.disconnectAction) {
                    ForEach(SettingsStore.DisconnectAction.allCases) { action in
                        Text(action.title).tag(action)
                    }
                }

                Picker(L10n.Settings.General.onAppSuspend, selection: $store.suspendAction) {
                    ForEach(SettingsStore.SuspendAction.allCases) { action in
                        Text(action.title).tag(action)
                    }
                }
            } header: {
                Text(L10n.Settings.General.sessionActions)
            } footer: {
                Text(L10n.Settings.General.sessionActionsDescription)
            }

            // Privacy Section
            Section {
                Toggle(L10n.Settings.General.streamerMode, isOn: $store.streamerModeEnabled)
            } header: {
                Text(L10n.Settings.General.privacy)
            } footer: {
                Text(L10n.Settings.General.streamerModeDescription)
            }
        }
        .navigationTitle(L10n.Nav.general)
        #if os(macOS)
        .formStyle(.grouped)
        #endif
    }

    private var registeredHosts: [ConsoleHost] {
        hostStore.hosts.filter { $0.isRegistered }
    }

    private var autoConnectHostBinding: Binding<UUID?> {
        Binding(
            get: { store.autoConnectHostId },
            set: { store.autoConnectHostId = $0 }
        )
    }
}

#Preview {
    NavigationStack {
        GeneralSettingsView()
            .environment(SettingsStore())
            .environment(HostStore())
    }
}
