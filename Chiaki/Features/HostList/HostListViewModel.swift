import Foundation

class HostListViewModel: ObservableObject {
    @Published var hosts: [ConsoleHost] = []
    
    init() {
        // Load mock data for now
        self.hosts = MockData.hosts
    }
    
    func addHost(_ host: ConsoleHost) {
        hosts.append(host)
    }
    
    func deleteHost(at offsets: IndexSet) {
        hosts.remove(atOffsets: offsets)
    }
    
    func wakeUp(_ host: ConsoleHost) {
        // Mock wakeup
        if let index = hosts.firstIndex(where: { $0.id == host.id }) {
            hosts[index].state = .online
        }
    }
}
