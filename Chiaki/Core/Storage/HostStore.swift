// SPDX-License-Identifier: AGPL-3.0-only
//
// HostStore.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Persistent storage for PlayStation hosts

import Foundation
import Observation

// MARK: - Host Store

/// Persistent storage for PlayStation hosts
@Observable
final class HostStore {
    // MARK: - Singleton

    @MainActor static let shared = HostStore()

    // MARK: - Properties

    private(set) var hosts: [ConsoleHost] = []

    /// Registered hosts that are not hidden
    var visibleRegisteredHosts: [ConsoleHost] {
        hosts.filter { $0.isRegistered && !$0.isHidden }
    }

    /// All registered hosts (including hidden)
    var registeredHosts: [ConsoleHost] {
        hosts.filter { $0.isRegistered }
    }

    /// Hidden hosts only
    var hiddenHosts: [ConsoleHost] {
        hosts.filter { $0.isHidden }
    }

    // MARK: - Private Properties

    private let userDefaults: UserDefaults
    private let hostsKey = "chiaki.savedHosts"

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadHosts()
    }

    // MARK: - CRUD Operations

    /// Add a new host
    func addHost(_ host: ConsoleHost) {
        // Check if host with same ID already exists
        if let index = hosts.firstIndex(where: { $0.id == host.id }) {
            hosts[index] = host
        } else {
            hosts.append(host)
        }
        saveHosts()
    }

    /// Update an existing host
    func updateHost(_ host: ConsoleHost) {
        guard let index = hosts.firstIndex(where: { $0.id == host.id }) else {
            // Host not found, add it
            addHost(host)
            return
        }
        hosts[index] = host
        saveHosts()
    }

    /// Remove a host
    func removeHost(_ host: ConsoleHost) {
        hosts.removeAll { $0.id == host.id }
        saveHosts()
    }

    /// Remove host by ID
    func removeHost(id: UUID) {
        hosts.removeAll { $0.id == id }
        saveHosts()
    }

    /// Hide a host (removes from main list but keeps registration)
    func hideHost(_ host: ConsoleHost) {
        guard let index = hosts.firstIndex(where: { $0.id == host.id }) else { return }
        hosts[index].isHidden = true
        saveHosts()
    }

    /// Hide host by ID
    func hideHost(id: UUID) {
        guard let index = hosts.firstIndex(where: { $0.id == id }) else { return }
        hosts[index].isHidden = true
        saveHosts()
    }

    /// Unhide a host (restore to main list)
    func unhideHost(_ host: ConsoleHost) {
        guard let index = hosts.firstIndex(where: { $0.id == host.id }) else { return }
        hosts[index].isHidden = false
        saveHosts()
    }

    /// Unhide host by ID
    func unhideHost(id: UUID) {
        guard let index = hosts.firstIndex(where: { $0.id == id }) else { return }
        hosts[index].isHidden = false
        saveHosts()
    }

    /// Unhide host by MAC address
    func unhideHost(byMac mac: String) {
        guard let index = hosts.firstIndex(where: { $0.macAddress == mac }) else { return }
        hosts[index].isHidden = false
        saveHosts()
    }

    /// Get host by ID
    func host(byId id: UUID) -> ConsoleHost? {
        hosts.first { $0.id == id }
    }

    /// Get host by address
    func host(byAddress address: String) -> ConsoleHost? {
        hosts.first { $0.address == address }
    }

    /// Get host by host ID (from discovery)
    func host(byHostId hostId: String) -> ConsoleHost? {
        // The host_id from discovery is typically the MAC address or similar identifier
        // We might need to add a hostId field to ConsoleHost, for now match by MAC
        hosts.first { $0.macAddress == hostId }
    }

    // MARK: - Registration

    /// Update host registration credentials
    func updateRegistration(for host: ConsoleHost, registKey: Data, rpKey: Data, rpKeyType: UInt32) {
        guard var updatedHost = self.host(byId: host.id) else { return }
        updatedHost.registKey = registKey
        updatedHost.rpKey = rpKey
        updatedHost.rpKeyType = rpKeyType
        updateHost(updatedHost)
    }

    /// Check if a host is registered
    func isRegistered(_ host: ConsoleHost) -> Bool {
        guard let storedHost = self.host(byId: host.id) else { return false }
        return storedHost.isRegistered
    }

    // MARK: - Persistence

    private func loadHosts() {
        guard let data = userDefaults.data(forKey: hostsKey) else {
            hosts = []
            return
        }

        do {
            let decoder = JSONDecoder()
            hosts = try decoder.decode([ConsoleHost].self, from: data)
            Logger.storage.info("Loaded \(self.hosts.count) hosts from storage")
        } catch {
            Logger.storage.error("Failed to decode hosts: \(error.localizedDescription)")
            hosts = []
        }
    }

    private func saveHosts() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(hosts)
            userDefaults.set(data, forKey: hostsKey)
            Logger.storage.debug("Saved \(self.hosts.count) hosts to storage")
        } catch {
            Logger.storage.error("Failed to encode hosts: \(error.localizedDescription)")
        }
    }

    // MARK: - Utilities

    /// Clear all stored hosts
    func clearAll() {
        hosts = []
        userDefaults.removeObject(forKey: hostsKey)
        Logger.storage.info("Cleared all stored hosts")
    }

    /// Export hosts as JSON data
    func exportHosts() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(hosts)
    }

    /// Merge discovered host with stored host
    func mergeDiscoveredHost(_ discovered: DiscoveredHost) -> ConsoleHost {
        // Try to find existing host by address or host ID
        if let existing = host(byAddress: discovered.address) ?? host(byHostId: discovered.id) {
            var merged = existing
            merged.state = discovered.state
            // Update address if it changed (e.g., DHCP reassignment)
            if merged.address != discovered.address {
                merged.address = discovered.address
                updateHost(merged)
            }
            return merged
        }

        // New host - create from discovered
        return discovered.toConsoleHost()
    }
}
