// SPDX-License-Identifier: AGPL-3.0-only
//
// HostManager.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Unified host management combining discovery and storage

import Foundation
import Combine

// MARK: - Host Manager

/// Unified host management service
/// Combines discovery service and persistent storage
@MainActor
final class HostManager: ObservableObject {
    // MARK: - Published Properties

    /// All known hosts (merged from storage and discovery)
    @Published private(set) var hosts: [ConsoleHost] = []

    /// Whether discovery is active
    @Published private(set) var isDiscovering: Bool = false

    /// Last error message
    @Published private(set) var lastError: String?

    // MARK: - Dependencies

    private let discoveryService: DiscoveryService
    private(set) var hostStore: HostStore

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Singleton

    static let shared = HostManager()

    // MARK: - Initialization

    init(discoveryService: DiscoveryService? = nil,
         hostStore: HostStore? = nil) {
        self.discoveryService = discoveryService ?? DiscoveryService()
        self.hostStore = hostStore ?? HostStore()

        setupBindings()
        loadStoredHosts()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Observe discovery service
        discoveryService.$discoveredHosts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] discovered in
                self?.mergeDiscoveredHosts(discovered)
            }
            .store(in: &cancellables)

        discoveryService.$isDiscovering
            .receive(on: DispatchQueue.main)
            .assign(to: &$isDiscovering)

        discoveryService.$lastError
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastError)

        // Note: HostStore uses @Observable, so changes are tracked via SwiftUI
        // and we refresh hosts directly when needed via loadStoredHosts()
    }

    private func loadStoredHosts() {
        hosts = hostStore.hosts
        Logger.discovery.info("Loaded \(self.hosts.count) stored hosts")
    }

    // MARK: - Discovery Control

    /// Start discovering PlayStation consoles
    func startDiscovery() {
        discoveryService.startDiscovery()
    }

    /// Stop discovering PlayStation consoles
    func stopDiscovery() {
        discoveryService.stopDiscovery()
    }

    /// Toggle discovery on/off
    func toggleDiscovery() {
        if isDiscovering {
            stopDiscovery()
        } else {
            startDiscovery()
        }
    }

    // MARK: - Host Management

    /// Add a host manually
    func addHost(_ host: ConsoleHost) {
        hostStore.addHost(host)
        syncHostsFromStore()
    }

    /// Add a host manually with basic info
    func addHost(nickname: String, address: String, isPS5: Bool) {
        let host = ConsoleHost(
            nickname: nickname,
            address: address,
            isPS5: isPS5
        )
        hostStore.addHost(host)
        syncHostsFromStore()
    }

    /// Update a host
    func updateHost(_ host: ConsoleHost) {
        hostStore.updateHost(host)
        syncHostsFromStore()
    }

    /// Remove a host
    func removeHost(_ host: ConsoleHost) {
        hostStore.removeHost(host)
        syncHostsFromStore()
    }

    /// Remove a host by ID
    func removeHost(id: UUID) {
        hostStore.removeHost(id: id)
        syncHostsFromStore()
    }

    /// Get a host by ID
    func host(byId id: UUID) -> ConsoleHost? {
        hosts.first { $0.id == id }
    }

    // MARK: - Wake Up

    /// Wake up a PlayStation console
    func wakeUp(_ host: ConsoleHost) async throws {
        try await discoveryService.wakeUp(host: host)
    }

    // MARK: - Registration

    /// Update host registration
    func updateRegistration(for host: ConsoleHost, registKey: Data, rpKey: Data, rpKeyType: UInt32) {
        hostStore.updateRegistration(for: host, registKey: registKey, rpKey: rpKey, rpKeyType: rpKeyType)
    }

    /// Check if host is registered
    func isRegistered(_ host: ConsoleHost) -> Bool {
        hostStore.isRegistered(host)
    }

    // MARK: - Host Merging

    private func mergeDiscoveredHosts(_ discovered: [DiscoveredHost]) {
        var mergedHosts = hostStore.hosts

        for discoveredHost in discovered {
            // Find existing host by address or create new
            if let index = mergedHosts.firstIndex(where: { $0.address == discoveredHost.address }) {
                // Update state of existing host
                mergedHosts[index].state = discoveredHost.state
            } else {
                // Check if we have a stored host with same MAC/hostId
                if let index = mergedHosts.firstIndex(where: { $0.macAddress == discoveredHost.id && !$0.macAddress.isEmpty }) {
                    // Update address and state
                    mergedHosts[index].address = discoveredHost.address
                    mergedHosts[index].state = discoveredHost.state
                } else {
                    // New discovered host - add as unregistered
                    let newHost = discoveredHost.toConsoleHost()
                    mergedHosts.append(newHost)
                }
            }
        }

        // Mark hosts not in discovery as offline (unless manually added with no discovery)
        let discoveredAddresses = Set(discovered.map { $0.address })
        for index in mergedHosts.indices {
            if !discoveredAddresses.contains(mergedHosts[index].address) &&
               mergedHosts[index].state != .offline {
                // Only mark as offline if we're actively discovering
                if isDiscovering {
                    mergedHosts[index].state = .offline
                }
            }
        }

        hosts = mergedHosts
    }

    /// Sync hosts from store, preserving discovery state
    private func syncHostsFromStore() {
        var updatedHosts = hostStore.hosts

        // Preserve state from currently discovered hosts
        for discoveredHost in discoveryService.discoveredHosts {
            if let index = updatedHosts.firstIndex(where: { $0.address == discoveredHost.address }) {
                updatedHosts[index].state = discoveredHost.state
            }
        }

        hosts = updatedHosts
    }

    // MARK: - Utilities

    /// Refresh host states
    func refresh() async {
        // Stop and restart discovery to get fresh results
        stopDiscovery()
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        startDiscovery()
    }

    /// Clear all hosts
    func clearAll() {
        hostStore.clearAll()
        hosts = []
    }
}
