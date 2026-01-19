import SwiftUI

struct HostListView: View {
    @State private var viewModel = HostListViewModel()
    @State private var showingAddHost = false
    @State private var registeringHost: ConsoleHost?
    @State private var showDeleteConfirmation = false
    @State private var indexSetToDelete: IndexSet?

    var body: some View {
        List {
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
        .navigationTitle("Hosts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddHost = true }) {
                    Label("Add Host", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddHost) {
            AddHostView(viewModel: viewModel)
        }
        .sheet(item: $registeringHost) { host in
            RegistrationView(hostStore: HostManager.shared.hostStore, initialAddress: host.address)
        }
        .refreshable {
            try? await Task.sleep(for: .seconds(1))
        }
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
            
            Button(action: { showingAddHost = true }) {
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
    }
}
