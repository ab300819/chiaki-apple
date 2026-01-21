import SwiftUI

struct HostListView: View {
    @Environment(NavigationManager.self) var navigationManager
    @State private var viewModel = HostListViewModel()
    @State private var registeringHost: ConsoleHost?
    @State private var settingPinHost: ConsoleHost?
    @State private var showDeleteConfirmation = false
    @State private var indexSetToDelete: IndexSet?
    @State private var selectedHostId: ConsoleHost.ID?
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
                    viewModel.deleteHost(at: indexSet)
                }
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.HostList.deleteConfirmMessage)
        }
        .navigationDestination(for: ConsoleHost.self) { host in
            StreamingView(host: host)
        }
        .toolbar {
            #if !os(tvOS)
            ToolbarItem(placement: .navigation) {
                Button(action: { viewModel.toggleDiscovery() }) {
                    Label(
                        viewModel.isDiscovering ? L10n.HostList.stopDiscovery : L10n.HostList.startDiscovery,
                        systemImage: viewModel.isDiscovering ? "wifi" : "wifi.slash"
                    )
                }
                .help(viewModel.isDiscovering ? L10n.HostList.stopDiscovery : L10n.HostList.startDiscovery)
            }
            #endif
            ToolbarItem(placement: .primaryAction) {
                Button(action: { navigationManager.showAddHostSheet = true }) {
                    Label(L10n.HostList.addHost, systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $navigationManager.showAddHostSheet) {
            AddHostView(viewModel: viewModel)
        }
        .sheet(item: $registeringHost) { host in
            RegistrationView(hostStore: HostManager.shared.hostStore, initialAddress: host.address)
        }
        .sheet(item: $settingPinHost) { host in
            ConsolePinView(host: host) { pin in
                if let pin = pin {
                    ConsolePinManager.shared.setPin(pin, for: host)
                } else {
                    ConsolePinManager.shared.clearPin(for: host)
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
                if let selectedId = selectedHostId, let host = viewModel.host(byId: selectedId) {
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
                            NavigationLink(value: host) {
                                TVHostCardView(host: host) {
                                    viewModel.wakeUp(host)
                                }
                            }
                            .buttonStyle(.plain)
                            .focused($focusedHost, equals: host.id)
                            .contextMenu {
                                if host.state == .standby {
                                    Button(L10n.HostList.wakeUp) {
                                        viewModel.wakeUp(host)
                                    }
                                }
                                Button {
                                    settingPinHost = host
                                } label: {
                                    Label(
                                        ConsolePinManager.shared.hasPin(for: host) ? String(localized: "consolePin.changePin") : String(localized: "consolePin.setPin"),
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
                            Button(action: { registeringHost = host }) {
                                TVHostCardView(host: host) {
                                    viewModel.wakeUp(host)
                                }
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
        List(selection: $selectedHostId) {
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
                                    ConsolePinManager.shared.hasPin(for: host) ? String(localized: "consolePin.changePin") : String(localized: "consolePin.setPin"),
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
                        Button(action: { registeringHost = host }) {
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
        .refreshable {
            await viewModel.refresh()
        }
        .navigationTitle(L10n.HostList.title)
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

            Button(action: { navigationManager.showAddHostSheet = true }) {
                Text(L10n.HostList.addHost)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
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
