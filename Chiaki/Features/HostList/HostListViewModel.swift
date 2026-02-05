// SPDX-License-Identifier: AGPL-3.0-only
//
// HostListViewModel.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// View model for the host list

import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class HostListViewModel {
    // MARK: - Properties

    /// Hosts are computed from HostManager to ensure @Observable tracking works
    /// Returns empty array if not yet initialized (safe for SwiftUI view init)
    var hosts: [ConsoleHost] {
        _hostManager?.hosts ?? []
    }

    /// Returns false if not yet initialized (safe for SwiftUI view init)
    var isDiscovering: Bool {
        _hostManager?.isDiscovering ?? false
    }

    var isLoading: Bool = true  // Start with loading state

    /// Local error message for ViewModel-specific errors
    private var localErrorMessage: String?

    /// Returns local error or hostManager error (nil-safe before initialization)
    var errorMessage: String? {
        get { localErrorMessage ?? _hostManager?.lastError }
        set { localErrorMessage = newValue }
    }

    // MARK: - Private Properties

    private var _hostManager: HostManager?
    private let pinManager: PinManaging
    private var isInitialized = false

    /// Safe accessor for host manager (force unwraps after initialization)
    /// Public for use by views that need to pass HostManager to subviews (e.g., RegistrationView)
    var hostManager: HostManager {
        guard let manager = _hostManager else {
            fatalError("HostListViewModel used before initialization. Call initializeIfNeeded() first.")
        }
        return manager
    }

    // MARK: - Initialization

    /// Initialize with dependencies
    /// - Parameters:
    ///   - hostManager: Host manager (defaults to shared, lazily initialized)
    ///   - pinManager: PIN manager (defaults to shared instance)
    init(hostManager: HostManager? = nil, pinManager: PinManaging? = nil) {
        self.pinManager = pinManager ?? ConsolePinManager.shared
        // Defer heavy initialization - don't access .shared here
        if let manager = hostManager {
            self._hostManager = manager
            isLoading = false
            isInitialized = true
        }
    }

    /// Call this from .task to initialize lazily
    func initializeIfNeeded() {
        guard !isInitialized else { return }
        isInitialized = true
        _hostManager = HostManager.shared
        isLoading = false
    }

    // MARK: - Discovery

    /// Start discovering PlayStation consoles
    func startDiscovery() {
        hostManager.startDiscovery()
    }

    /**
     * Start discovery if not already running (Auto-discovery)
     * @requirement F-032
     * @satisfies AC-111
     */
    func startDiscoveryIfNeeded() {
        guard !isDiscovering else { return }
        startDiscovery()
    }

    /// Stop discovering PlayStation consoles
    func stopDiscovery() {
        hostManager.stopDiscovery()
    }

    /**
     * Stop discovery if running (Lifecycle optimization)
     * @requirement F-032
     * @satisfies AC-112
     */
    func stopDiscoveryIfNeeded() {
        guard isDiscovering else { return }
        stopDiscovery()
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

    /// Delete hosts by IDs (batch delete)
    /// @satisfies INS-052 - 主机列表批量删除
    func deleteHosts(ids: Set<UUID>) {
        for id in ids {
            hostManager.removeHost(id: id)
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

// MARK: - PIN Management
/// @requirement F-027 - UI 层 MVVM 合规重构
/// @satisfies AC-090 - HostListViewModel PIN 代理

extension HostListViewModel {
    /// Check if host has a stored PIN
    /// - Parameter host: Host to check
    /// - Returns: true if PIN exists
    func hasPin(for host: ConsoleHost) -> Bool {
        pinManager.hasPin(for: host)
    }

    /// Set PIN for a host
    /// - Parameters:
    ///   - pin: PIN to store
    ///   - host: Host to associate PIN with
    func setPin(_ pin: String, for host: ConsoleHost) {
        pinManager.setPin(pin, for: host)
    }

    /// Clear PIN for a host
    /// - Parameter host: Host to clear PIN for
    func clearPin(for host: ConsoleHost) {
        pinManager.clearPin(for: host)
    }
}

// MARK: - Preview Support

extension HostListViewModel {
    /// Create a view model with mock data for previews
    /// Note: Uses shared HostManager, preview data comes from MockData
    static func preview() -> HostListViewModel {
        HostListViewModel(hostManager: HostManager.shared)
    }
}
