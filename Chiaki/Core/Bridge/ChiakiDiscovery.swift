// SPDX-License-Identifier: AGPL-3.0-only
//
// ChiakiDiscovery.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Swift wrapper for libchiaki discovery service
// Handles PlayStation console discovery on local network

import Foundation
import Combine
import Network

// MARK: - Discovered Host

/// Discovered PlayStation host information
struct DiscoveredHost: Identifiable, Equatable, Hashable {
    let id: String  // host_id from discovery
    let address: String
    let state: HostState
    let isPS5: Bool
    let hostName: String
    let systemVersion: String?
    let runningApp: String?
    let runningAppId: String?

    // Create a ConsoleHost from discovered host (for merging with stored hosts)
    func toConsoleHost(mergedWith existing: ConsoleHost? = nil) -> ConsoleHost {
        var host = existing ?? ConsoleHost(
            nickname: hostName,
            address: address,
            isPS5: isPS5
        )
        host.state = state
        // Update address if changed
        if host.address != address {
            host.address = address
        }
        return host
    }
}

// MARK: - Discovery Service

/// PlayStation console discovery service
/// Note: Full libchiaki integration pending - currently uses mock discovery
@MainActor
final class DiscoveryService: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var discoveredHosts: [DiscoveredHost] = []
    @Published private(set) var isDiscovering: Bool = false
    @Published private(set) var lastError: String?

    // MARK: - Private Properties

    private var discoveryTimer: Timer?
    private var isInitialized = false

    // MARK: - Initialization

    init() {
        Logger.discovery.info("DiscoveryService initialized")
    }

    deinit {
        // Timer cleanup - safe to access in deinit
        discoveryTimer?.invalidate()
    }

    // MARK: - Discovery Control

    /// Start discovering PlayStation consoles on the local network
    func startDiscovery() {
        guard !isDiscovering else { return }

        isDiscovering = true
        lastError = nil
        Logger.discovery.info("Discovery started")

        // Start periodic discovery
        // TODO: Replace with actual libchiaki discovery service
        startPeriodicDiscovery()
    }

    /// Stop discovering PlayStation consoles
    func stopDiscovery() {
        guard isDiscovering else { return }

        discoveryTimer?.invalidate()
        discoveryTimer = nil
        isDiscovering = false
        Logger.discovery.info("Discovery stopped")
    }

    // MARK: - Wake Up

    /// Send wake-up packet to a PlayStation console
    /// - Parameters:
    ///   - host: The host to wake up
    func wakeUp(host: ConsoleHost) async throws {
        guard !host.address.isEmpty else {
            throw DiscoveryError.invalidAddress
        }
        guard !host.registKey.isEmpty else {
            throw DiscoveryError.notRegistered
        }

        Logger.discovery.info("Sending wake-up to \(host.nickname) at \(host.address)")

        // TODO: Implement actual wake-up using libchiaki
        // For now, simulate wake-up by waiting and updating state
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms

        // In real implementation, this would send a UDP wake-up packet
        // using chiaki_discovery_send with CHIAKI_DISCOVERY_CMD_WAKEUP

        Logger.discovery.info("Wake-up packet sent (simulated)")
    }

    // MARK: - Private Methods

    private func startPeriodicDiscovery() {
        // Send initial discovery
        performDiscovery()

        // Schedule periodic discovery
        discoveryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performDiscovery()
            }
        }
    }

    private func performDiscovery() {
        // TODO: Replace with actual libchiaki discovery
        // This is a placeholder that broadcasts UDP discovery packets
        // and collects responses from PlayStation consoles

        // For now, keep the current discovered hosts
        // Real implementation would:
        // 1. Send SRCH packet to broadcast address on port 987 (PS4) and 9302 (PS5)
        // 2. Collect responses and parse ChiakiDiscoveryHost data
        // 3. Update discoveredHosts array

        Logger.discovery.debug("Discovery ping sent")
    }
}

// MARK: - Discovery Error

enum DiscoveryError: Error, LocalizedError {
    case invalidAddress
    case notRegistered
    case notInitialized
    case initializationFailed
    case wakeUpFailed

    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return "Invalid host address"
        case .notRegistered:
            return "Host is not registered"
        case .notInitialized:
            return "Discovery service not initialized"
        case .initializationFailed:
            return "Failed to initialize discovery"
        case .wakeUpFailed:
            return "Failed to send wake-up packet"
        }
    }
}
