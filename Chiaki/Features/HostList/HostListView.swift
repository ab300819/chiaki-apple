import SwiftUI

struct HostListView: View {
    @Environment(NavigationManager.self) var navigationManager
    @State private var viewModel = HostListViewModel()
    @State private var registeringHost: ConsoleHost?
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
        .confirmationDialog("Delete Host?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let indexSet = indexSetToDelete {
                    viewModel.deleteHost(at: indexSet)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .navigationDestination(for: ConsoleHost.self) { host in
            StreamingView(host: host)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { navigationManager.showAddHostSheet = true }) {
                    Label("Add Host", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $navigationManager.showAddHostSheet) {
            AddHostView(viewModel: viewModel)
        }
        .sheet(item: $registeringHost) { host in
            RegistrationView(hostStore: HostManager.shared.hostStore, initialAddress: host.address)
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
                                    Button("Wake Up") {
                                        viewModel.wakeUp(host)
                                    }
                                }
                                Button("Delete", role: .destructive) {
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
        .navigationTitle("Hosts")
        .onAppear {
            if focusedHost == nil {
                focusedHost = viewModel.hosts.first?.id
            }
        }
    }
    #endif

    private var iOSBody: some View {
        List(selection: $selectedHostId) {
            if viewModel.hosts.isEmpty {
                emptyStateView
            } else {
                ForEach(viewModel.hosts) { host in
                    if host.isRegistered {
                        NavigationLink(value: host) {
                            HostRowView(host: host) {
                                viewModel.wakeUp(host)
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
        .navigationTitle("Hosts")
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "gamecontroller.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Hosts Found")
                .font(.headline)
            Text("Add a host manually or wait for discovery.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: { navigationManager.showAddHostSheet = true }) {
                Text("Add Host")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top, 12)
            .buttonStyle(.plain)
            .accessibilityLabel("Add a new host manually")
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
