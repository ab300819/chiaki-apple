// SPDX-License-Identifier: AGPL-3.0-only
//
// HostManager.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Unified host management combining discovery and storage

import Foundation
import Observation
import Combine

// MARK: - Host Manager

/// Unified host management service
/// Combines discovery service and persistent storage
@Observable
@MainActor
final class HostManager {
    // MARK: - Properties

    /// All known hosts (merged from storage and discovery)
    private(set) var hosts: [ConsoleHost] = []

    /// Whether discovery is active
    var isDiscovering: Bool {
        discoveryService.isDiscovering
    }

    /// Last error message
    var lastError: String? {
        discoveryService.lastError
    }

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
        self.hostStore = hostStore ?? HostStore.shared

        setupBindings()
        loadStoredHosts()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Observe discovery service via callback
        discoveryService.onHostsUpdated = { [weak self] discovered in
            self?.mergeDiscoveredHosts(discovered)
        }

        // Observe HostStore changes using withObservationTracking
        // This ensures HostManager.hosts syncs when hostStore.hosts changes
        observeHostStoreChanges()
    }

    /// Continuously observe HostStore.hosts for changes
    private func observeHostStoreChanges() {
        withObservationTracking {
            _ = hostStore.hosts
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.syncHostsFromStore()
                self?.observeHostStoreChanges()
            }
        }
    }

    private func loadStoredHosts() {
        // Filter out hidden hosts from the main list
        hosts = hostStore.hosts.filter { !$0.isHidden }
        Logger.discovery.info("Loaded \(self.hosts.count) visible hosts")
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
        // Filter out hidden hosts from merge
        var mergedHosts = hostStore.hosts.filter { !$0.isHidden }

        for discoveredHost in discovered {
            // Find existing host by address or create new
            if let index = mergedHosts.firstIndex(where: { $0.address == discoveredHost.address }) {
                // Update state and running app info of existing host
                mergedHosts[index].state = discoveredHost.state
                mergedHosts[index].runningApp = discoveredHost.runningApp
                mergedHosts[index].runningAppId = discoveredHost.runningAppId
            } else {
                // Check if we have a stored host with same MAC/hostId
                if let index = mergedHosts.firstIndex(where: { $0.macAddress == discoveredHost.id && !$0.macAddress.isEmpty }) {
                    // Update address, state, and running app info
                    mergedHosts[index].address = discoveredHost.address
                    mergedHosts[index].state = discoveredHost.state
                    mergedHosts[index].runningApp = discoveredHost.runningApp
                    mergedHosts[index].runningAppId = discoveredHost.runningAppId
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
                    // Clear running app info when offline
                    mergedHosts[index].runningApp = nil
                    mergedHosts[index].runningAppId = nil
                }
            }
        }

        hosts = mergedHosts
    }

    /// Sync hosts from store, preserving discovery state
    private func syncHostsFromStore() {
        // Filter out hidden hosts
        var updatedHosts = hostStore.hosts.filter { !$0.isHidden }

        // Preserve state and running app info from currently discovered hosts
        for discoveredHost in discoveryService.discoveredHosts {
            if let index = updatedHosts.firstIndex(where: { $0.address == discoveredHost.address }) {
                updatedHosts[index].state = discoveredHost.state
                updatedHosts[index].runningApp = discoveredHost.runningApp
                updatedHosts[index].runningAppId = discoveredHost.runningAppId
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
