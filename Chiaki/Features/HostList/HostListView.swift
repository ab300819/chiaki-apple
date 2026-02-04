// SPDX-License-Identifier: AGPL-3.0-only
//
// HostListView.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Host list view with MVVM singleton decoupling
//
// @requirement F-027 - UI 层 MVVM 合规重构
// @satisfies AC-090 - HostListView Singleton 解耦

import SwiftUI

/// Host list view using MVVM pattern
/// @requirement F-027 - UI 层 MVVM 合规重构
struct HostListView: View {
    @Environment(NavigationManager.self) var navigationManager
    @State private var viewModel = HostListViewModel()
    @State private var registeringHost: ConsoleHost?
    @State private var settingPinHost: ConsoleHost?
    @State private var showDeleteConfirmation = false
    @State private var indexSetToDelete: IndexSet?
    @State private var selectedHostIds: Set<ConsoleHost.ID> = []
    @State private var isEditMode = false
    @FocusState private var focusedHost: ConsoleHost.ID?

    var body: some View {
        @Bindable var navigationManager = navigationManager
        Group {
            #if os(tvOS)
            tvOSBody
            #else
            iOSBody
            #endif
        }
        .confirmationDialog(L10n.HostList.deleteConfirmTitle, isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button(L10n.Common.delete, role: .destructive) {
                if let indexSet = indexSetToDelete {
                    // Single delete via swipe
                    viewModel.deleteHost(at: indexSet)
                    indexSetToDelete = nil
                } else if !selectedHostIds.isEmpty {
                    // Batch delete via selection
                    viewModel.deleteHosts(ids: selectedHostIds)
                    selectedHostIds.removeAll()
                    isEditMode = false
                }
            }
            Button(L10n.Common.cancel, role: .cancel) {
                indexSetToDelete = nil
            }
        } message: {
            if selectedHostIds.count > 1 {
                Text(String(localized: "hostList.deleteMultipleConfirmMessage \(selectedHostIds.count)"))
            } else {
                Text(L10n.HostList.deleteConfirmMessage)
            }
        }
        .navigationDestination(for: ConsoleHost.self) { host in
            StreamingView(host: host)
        }
        .toolbar {
            #if !os(tvOS)
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    HapticFeedback.button()
                    viewModel.toggleDiscovery()
                }) {
                    Label(
                        viewModel.isDiscovering ? L10n.HostList.stopDiscovery : L10n.HostList.startDiscovery,
                        systemImage: viewModel.isDiscovering ? "wifi" : "wifi.slash"
                    )
                }
                .help(viewModel.isDiscovering ? L10n.HostList.stopDiscovery : L10n.HostList.startDiscovery)
            }
            #endif
            #if os(macOS)
            // macOS: Delete selected hosts (use Cmd+Click to multi-select in list)
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label(String(localized: "hostList.deleteSelected \(selectedHostIds.count)"), systemImage: "trash")
                }
                .disabled(selectedHostIds.isEmpty)
                .help(String(localized: "hostList.deleteSelectedHelp"))
            }
            #endif
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    HapticFeedback.button()
                    navigationManager.showAddHostSheet = true
                }) {
                    Label(L10n.HostList.addHost, systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $navigationManager.showAddHostSheet) {
            AddHostView(viewModel: viewModel)
        }
        .sheet(item: $registeringHost) { host in
            RegistrationView(hostManager: viewModel.hostManager, initialAddress: host.address)
        }
        .sheet(item: $settingPinHost) { host in
            ConsolePinView(host: host) { pin in
                if let pin = pin {
                    viewModel.setPin(pin, for: host)
                } else {
                    viewModel.clearPin(for: host)
                }
            }
        }
        .onChange(of: navigationManager.refreshDiscoveryTrigger) { _, newValue in
            if newValue {
                Task {
                    await viewModel.refresh()
                    navigationManager.refreshDiscoveryTrigger = false
                }
            }
        }
        .onChange(of: navigationManager.wakeUpSelectedHostTrigger) { _, newValue in
            if newValue {
                if let selectedId = selectedHostIds.first, let host = viewModel.host(byId: selectedId) {
                    viewModel.wakeUp(host)
                }
                navigationManager.wakeUpSelectedHostTrigger = false
            }
        }
        .task {
            viewModel.initializeIfNeeded()
        }
    }
    
    #if os(tvOS)
    private var tvOSBody: some View {
        ScrollView {
            if viewModel.hosts.isEmpty {
                 emptyStateView
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 400, maximum: 500), spacing: 50)], spacing: 50) {
                    ForEach(viewModel.hosts) { host in
                        if host.isRegistered {
                            /**
                             * Registered host card with quick action bar
                             * @satisfies AC-065 - 主机快速操作栏
                             */
                            NavigationLink(value: host) {
                                TVHostCardView(
                                    host: host,
                                    onWakeUp: {
                                        HapticFeedback.button()
                                        viewModel.wakeUp(host)
                                    },
                                    onConnect: {
                                        // Connect is handled by NavigationLink
                                    },
                                    onPin: {
                                        HapticFeedback.button()
                                        settingPinHost = host
                                    },
                                    onDelete: {
                                        HapticFeedback.button()
                                        if let index = viewModel.hosts.firstIndex(of: host) {
                                            viewModel.deleteHost(at: IndexSet(integer: index))
                                        }
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                            .focused($focusedHost, equals: host.id)
                            .contextMenu {
                                // Context menu preserved as fallback
                                // @satisfies AC-065 - 长按菜单保留作为备选方案
                                if host.state == .standby {
                                    Button(L10n.HostList.wakeUp) {
                                        viewModel.wakeUp(host)
                                    }
                                }
                                Button {
                                    settingPinHost = host
                                } label: {
                                    Label(
                                        viewModel.hasPin(for: host) ? String(localized: "consolePin.changePin") : String(localized: "consolePin.setPin"),
                                        systemImage: "lock"
                                    )
                                }
                                Button(L10n.Common.delete, role: .destructive) {
                                    if let index = viewModel.hosts.firstIndex(of: host) {
                                        viewModel.deleteHost(at: IndexSet(integer: index))
                                    }
                                }
                            }
                        } else {
                            Button(action: {
                                HapticFeedback.button()
                                registeringHost = host
                            }) {
                                TVHostCardView(
                                    host: host,
                                    onWakeUp: {
                                        HapticFeedback.button()
                                        viewModel.wakeUp(host)
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                            .focused($focusedHost, equals: host.id)
                        }
                    }
                }
                .padding(50)
            }
        }
        .navigationTitle(L10n.HostList.title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 8) {
                    if viewModel.isDiscovering {
                        Image(systemName: "wifi")
                            .foregroundStyle(.green)
                            .symbolEffect(.pulse)
                    }
                    Button(action: { viewModel.toggleDiscovery() }) {
                        Text(viewModel.isDiscovering ? L10n.HostList.stop : L10n.HostList.discover)
                    }
                }
            }
        }
        .onAppear {
            if focusedHost == nil {
                focusedHost = viewModel.hosts.first?.id
            }
        }
    }
    #endif

    private var iOSBody: some View {
        List(selection: $selectedHostIds) {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if viewModel.hosts.isEmpty {
                emptyStateView
            } else {
                ForEach(viewModel.hosts) { host in
                    if host.isRegistered {
                        NavigationLink(value: host) {
                            HostRowView(host: host) {
                                viewModel.wakeUp(host)
                            }
                        }
                        .contextMenu {
                            if host.state == .standby {
                                Button(L10n.HostList.wakeUp, systemImage: "power") {
                                    viewModel.wakeUp(host)
                                }
                            }
                            Button {
                                settingPinHost = host
                            } label: {
                                Label(
                                    viewModel.hasPin(for: host) ? String(localized: "consolePin.changePin") : String(localized: "consolePin.setPin"),
                                    systemImage: "lock"
                                )
                            }
                            Button(L10n.Common.delete, systemImage: "trash", role: .destructive) {
                                if let index = viewModel.hosts.firstIndex(of: host) {
                                    indexSetToDelete = IndexSet(integer: index)
                                    showDeleteConfirmation = true
                                }
                            }
                        }
                    } else {
                        Button(action: {
                            HapticFeedback.button()
                            registeringHost = host
                        }) {
                            HostRowView(host: host) {
                                viewModel.wakeUp(host)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .onDelete { indexSet in
                    indexSetToDelete = indexSet
                    showDeleteConfirmation = true
                }
            }
        }
        #if os(iOS)
        .environment(\.editMode, .constant(isEditMode ? .active : .inactive))
        #endif
        .refreshable {
            await viewModel.refresh()
        }
        .navigationTitle(L10n.HostList.title)
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !viewModel.hosts.isEmpty {
                    Button(isEditMode ? String(localized: "common.done") : String(localized: "common.edit")) {
                        withAnimation {
                            isEditMode.toggle()
                            if !isEditMode {
                                selectedHostIds.removeAll()
                            }
                        }
                    }
                }
            }
            ToolbarItem(placement: .bottomBar) {
                if isEditMode && !selectedHostIds.isEmpty {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label(String(localized: "hostList.deleteSelected \(selectedHostIds.count)"), systemImage: "trash")
                    }
                }
            }
        }
        #endif
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "gamecontroller.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(L10n.HostList.noHostsFound)
                .font(.headline)
            Text(L10n.HostList.noHostsDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: { 
                HapticFeedback.button()
                navigationManager.showAddHostSheet = true 
            }) {
                Text(L10n.HostList.addHost)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(.rect(cornerRadius: 8))
            }
            .padding(.top, 12)
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "accessibility.addHostManually"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .listRowBackground(Color.clear)
    }
}

#Preview {
    NavigationStack {
        HostListView()
            .environment(NavigationManager())
            .environment(SettingsStore())
    }
}
