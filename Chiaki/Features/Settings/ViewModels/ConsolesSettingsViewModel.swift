// SPDX-License-Identifier: AGPL-3.0-only
//
// ConsolesSettingsViewModel.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// ViewModel for console management settings
//
// @requirement F-027 - UI 层 MVVM 合规重构
// @satisfies AC-094 - ConsolesSettingsViewModel

import Foundation
import Observation

/// ViewModel for console management settings
/// @requirement F-027 - UI 层 MVVM 合规重构
/// @satisfies AC-094 - ConsolesSettingsViewModel
@Observable
@MainActor
final class ConsolesSettingsViewModel {
    // MARK: - Dependencies

    private let hostStore: HostStore
    private let pinManager: PinManaging

    // MARK: - Computed Properties

    /// All registered hosts (including hidden)
    var registeredHosts: [ConsoleHost] {
        hostStore.registeredHosts
    }

    /// Hidden hosts only
    var hiddenHosts: [ConsoleHost] {
        hostStore.hiddenHosts
    }

    // MARK: - Initialization

    /// Initialize with dependencies
    /// - Parameters:
    ///   - hostStore: Host store (defaults to shared instance)
    ///   - pinManager: PIN manager (defaults to shared instance)
    init(hostStore: HostStore? = nil, pinManager: PinManaging? = nil) {
        self.hostStore = hostStore ?? HostStore.shared
        self.pinManager = pinManager ?? ConsolePinManager.shared
    }

    // MARK: - Host Actions

    /// Remove a host and clear associated PIN
    /// - Parameter host: Host to remove
    func removeHost(_ host: ConsoleHost) {
        // Clear PIN before removing host
        pinManager.clearPin(for: host)
        hostStore.removeHost(host)
    }

    /// Hide a host from the main list
    /// - Parameter host: Host to hide
    func hideHost(_ host: ConsoleHost) {
        hostStore.hideHost(host)
    }

    /// Unhide a host to restore to main list
    /// - Parameter host: Host to unhide
    func unhideHost(_ host: ConsoleHost) {
        hostStore.unhideHost(host)
    }

    // MARK: - PIN Proxy Methods

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
