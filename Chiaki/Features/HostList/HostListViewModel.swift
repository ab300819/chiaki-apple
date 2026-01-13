import Foundation
import Observation
import SwiftUI

@Observable
final class HostListViewModel {
    var hosts: [ConsoleHost] = []

    init() {
        loadMockData()
    }

    private func loadMockData() {
        var ps5 = MockData.hostPS5
        ps5.state = .online

        var ps4 = MockData.hostPS4
        ps4.state = .standby

        var unregistered = MockData.hostUnregistered
        unregistered.state = .offline

        self.hosts = [ps5, ps4, unregistered]
    }

    func addHost(_ host: ConsoleHost) {
        hosts.append(host)
    }

    func deleteHost(at offsets: IndexSet) {
        hosts.remove(atOffsets: offsets)
    }

    func wakeUp(_ host: ConsoleHost) {
        if let index = hosts.firstIndex(where: { $0.id == host.id }) {
            hosts[index].state = .online
        }
    }

    func connect(to host: ConsoleHost) {
        // Placeholder for connection logic
    }
}
