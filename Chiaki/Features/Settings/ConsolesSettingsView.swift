// SPDX-License-Identifier: AGPL-3.0-only
//
// ConsolesSettingsView.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// View for managing registered consoles
//
// @requirement F-027 - UI 层 MVVM 合规重构
// @satisfies AC-094 - ConsolesSettingsView 使用 ViewModel

import SwiftUI

/// Console settings view using MVVM pattern
/// @requirement F-027 - UI 层 MVVM 合规重构
struct ConsolesSettingsView: View {
    @Environment(SettingsStore.self) var settingsStore
    @State private var viewModel = ConsolesSettingsViewModel()

    @State private var showDeleteConfirmation = false
    @State private var showHideConfirmation = false
    @State private var showUnhideConfirmation = false
    @State private var selectedHost: ConsoleHost?

    var body: some View {
        Form {
            // Registered Consoles Section
            Section {
                if viewModel.registeredHosts.isEmpty {
                    Text(L10n.Settings.Consoles.noRegistered)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.registeredHosts) { host in
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
                Text(L10n.Settings.Consoles.registeredConsoles)
            } footer: {
                Text(L10n.Settings.Consoles.registeredDescription)
            }

            // Hidden Consoles Section
            if !viewModel.hiddenHosts.isEmpty {
                Section {
                    ForEach(viewModel.hiddenHosts) { host in
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
                    Text(L10n.Settings.Consoles.hiddenConsoles)
                } footer: {
                    Text(L10n.Settings.Consoles.hiddenDescription)
                }
            }
        }
        .navigationTitle(L10n.Settings.Consoles.title)
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .confirmationDialog(
            String(localized: "settings.consoles.deleteTitle"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.Common.delete, role: .destructive) {
                if let host = selectedHost {
                    viewModel.removeHost(host)
                }
                selectedHost = nil
            }
            Button(L10n.Common.cancel, role: .cancel) {
                selectedHost = nil
            }
        } message: {
            if let host = selectedHost {
                Text(String(localized: "settings.consoles.deleteConfirm \(host.nickname)"))
            }
        }
        .confirmationDialog(
            String(localized: "settings.consoles.hideTitle"),
            isPresented: $showHideConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.Common.hide) {
                if let host = selectedHost {
                    viewModel.hideHost(host)
                }
                selectedHost = nil
            }
            Button(L10n.Common.cancel, role: .cancel) {
                selectedHost = nil
            }
        } message: {
            if let host = selectedHost {
                Text(String(localized: "settings.consoles.hideConfirm \(host.nickname)"))
            }
        }
        .confirmationDialog(
            String(localized: "settings.consoles.unhideTitle"),
            isPresented: $showUnhideConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.Common.unhide) {
                if let host = selectedHost {
                    viewModel.unhideHost(host)
                }
                selectedHost = nil
            }
            Button(L10n.Common.cancel, role: .cancel) {
                selectedHost = nil
            }
        } message: {
            if let host = selectedHost {
                Text(String(localized: "settings.consoles.unhideConfirm \(host.nickname)"))
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
                        Text(String(localized: "common.hidden"))
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
                    Label(L10n.Common.hide, systemImage: "eye.slash")
                }
                Button(role: .destructive, action: onDelete) {
                    Label(L10n.Common.delete, systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            #else
            HStack(spacing: 12) {
                Button(L10n.Common.hide, action: onHide)
                    .buttonStyle(.bordered)

                Button(L10n.Common.delete, role: .destructive, action: onDelete)
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

            Button(L10n.Common.unhide, action: onUnhide)
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
            .environment(SettingsStore())
    }
}
