// SPDX-License-Identifier: AGPL-3.0-only
//
// HostListViewModel.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// View model for the host list

import Foundation
import Observation
import SwiftUI
import Combine

@Observable
@MainActor
final class HostListViewModel {
    // MARK: - Properties

    var hosts: [ConsoleHost] = []
    var isDiscovering: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Private Properties

    private let hostManager: HostManager
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(hostManager: HostManager = .shared) {
        self.hostManager = hostManager
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Observe host manager
        hostManager.$hosts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hosts in
                self?.hosts = hosts
            }
            .store(in: &cancellables)

        hostManager.$isDiscovering
            .receive(on: DispatchQueue.main)
            .sink { [weak self] discovering in
                self?.isDiscovering = discovering
            }
            .store(in: &cancellables)

        hostManager.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.errorMessage = error
            }
            .store(in: &cancellables)
    }

    // MARK: - Discovery

    /// Start discovering PlayStation consoles
    func startDiscovery() {
        hostManager.startDiscovery()
    }

    /// Stop discovering PlayStation consoles
    func stopDiscovery() {
        hostManager.stopDiscovery()
    }

    /// Toggle discovery on/off
    func toggleDiscovery() {
        hostManager.toggleDiscovery()
    }

    /// Refresh host list
    func refresh() async {
        isLoading = true
        await hostManager.refresh()
        isLoading = false
    }

    // MARK: - Host Management

    /// Add a host
    func addHost(_ host: ConsoleHost) {
        hostManager.addHost(host)
    }

    /// Add a host with basic info
    func addHost(nickname: String, address: String, isPS5: Bool) {
        hostManager.addHost(nickname: nickname, address: address, isPS5: isPS5)
    }

    /// Delete hosts at offsets
    func deleteHost(at offsets: IndexSet) {
        for index in offsets {
            let host = hosts[index]
            hostManager.removeHost(host)
        }
    }

    /// Remove a specific host
    func removeHost(_ host: ConsoleHost) {
        hostManager.removeHost(host)
    }

    // MARK: - Wake Up

    /// Wake up a PlayStation console
    func wakeUp(_ host: ConsoleHost) {
        Task {
            do {
                try await hostManager.wakeUp(host)
                // Update will come through the binding when discovery detects the host
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Connection

    /// Connect to a PlayStation console
    func connect(to host: ConsoleHost) {
        // Check if host is registered
        guard host.isRegistered else {
            errorMessage = "Host is not registered. Please register first."
            return
        }

        // Connection will be handled by StreamingView/StreamingViewModel
        // This is a navigation trigger, actual connection happens elsewhere
    }

    /// Check if a host can be connected to
    func canConnect(to host: ConsoleHost) -> Bool {
        host.state == .online && host.isRegistered
    }

    // MARK: - Registration

    /// Check if host needs registration
    func needsRegistration(_ host: ConsoleHost) -> Bool {
        !host.isRegistered
    }

    // MARK: - Utilities

    /// Dismiss error
    func dismissError() {
        errorMessage = nil
    }

    /// Get host by ID
    func host(byId id: UUID) -> ConsoleHost? {
        hosts.first { $0.id == id }
    }
}

// MARK: - Preview Support

extension HostListViewModel {
    /// Create a view model with mock data for previews
    static func preview() -> HostListViewModel {
        let vm = HostListViewModel(hostManager: HostManager())

        // Add mock hosts directly
        var ps5 = ConsoleHost(
            nickname: "PlayStation 5",
            address: "192.168.1.100",
            isPS5: true,
            registKey: 12345
        )
        ps5.state = .online

        var ps4 = ConsoleHost(
            nickname: "PlayStation 4",
            address: "192.168.1.101",
            isPS5: false,
            registKey: 67890
        )
        ps4.state = .standby

        var unregistered = ConsoleHost(
            nickname: "New PlayStation",
            address: "192.168.1.102",
            isPS5: true
        )
        unregistered.state = .online

        vm.hosts = [ps5, ps4, unregistered]
        return vm
    }
}
