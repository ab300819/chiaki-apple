import SwiftUI

struct HostListView: View {
    @State private var viewModel = HostListViewModel()
    @State private var showingAddHost = false

    var body: some View {
        List {
            if viewModel.hosts.isEmpty {
                emptyStateView
            } else {
                ForEach(viewModel.hosts) { host in
                    HostRowView(host: host) {
                        viewModel.wakeUp(host)
                    }
                }
                .onDelete(perform: viewModel.deleteHost)
            }
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
