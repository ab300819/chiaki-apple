// SPDX-License-Identifier: AGPL-3.0-only
//
// ConsolePinManager.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Secure storage and verification for console access PINs

import Foundation

/// Manages 4-digit PIN codes for console access security
final class ConsolePinManager: @unchecked Sendable {
    // MARK: - Singleton

    static let shared = ConsolePinManager()

    // MARK: - Constants

    private let keyPrefix = "console.pin."
    private let keychain = KeychainManager.shared

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Set a PIN for a specific host
    /// - Parameters:
    ///   - pin: 4-digit PIN string
    ///   - host: The console host to protect
    func setPin(_ pin: String, for host: ConsoleHost) {
        guard isValidPin(pin) else {
            Logger.storage.warning("Attempted to set invalid PIN format")
            return
        }

        let key = pinKey(for: host)
        do {
            try keychain.save(key: key, string: pin)
            Logger.storage.info("PIN set for host: \(host.nickname)")
        } catch {
            Logger.storage.error("Failed to save PIN: \(error.localizedDescription)")
        }
    }

    /// Clear the PIN for a specific host
    /// - Parameter host: The console host to unprotect
    func clearPin(for host: ConsoleHost) {
        let key = pinKey(for: host)
        do {
            try keychain.delete(key: key)
            Logger.storage.info("PIN cleared for host: \(host.nickname)")
        } catch {
            Logger.storage.error("Failed to clear PIN: \(error.localizedDescription)")
        }
    }

    /// Check if a host has a PIN set
    /// - Parameter host: The console host to check
    /// - Returns: true if a PIN is set
    func hasPin(for host: ConsoleHost) -> Bool {
        let key = pinKey(for: host)
        do {
            _ = try keychain.loadString(key: key)
            return true
        } catch {
            return false
        }
    }

    /// Verify a PIN for a specific host
    /// - Parameters:
    ///   - pin: PIN to verify
    ///   - host: The console host
    /// - Returns: true if the PIN matches
    func verifyPin(_ pin: String, for host: ConsoleHost) -> Bool {
        let key = pinKey(for: host)
        do {
            let storedPin = try keychain.loadString(key: key)
            return storedPin == pin
        } catch {
            // No PIN stored means verification passes (no protection)
            return true
        }
    }

    /// Check if connection to host requires PIN verification
    /// - Parameter host: The console host
    /// - Returns: true if PIN entry is required before connecting
    func requiresPinEntry(for host: ConsoleHost) -> Bool {
        hasPin(for: host)
    }

    /// Get the PIN for a specific host, if present
    /// - Parameter host: The console host
    /// - Returns: Stored PIN or nil if not found
    func getPin(for host: ConsoleHost) -> String? {
        let key = pinKey(for: host)
        do {
            return try keychain.loadString(key: key)
        } catch {
            return nil
        }
    }

    // MARK: - Private Methods

    private func pinKey(for host: ConsoleHost) -> String {
        "\(keyPrefix)\(host.id.uuidString)"
    }

    private func isValidPin(_ pin: String) -> Bool {
        pin.count == 4 && pin.allSatisfy { $0.isNumber }
    }
}

/// @requirement F-027 - UI 层 MVVM 合规重构
/// @satisfies AC-095 - 协议抽象: PinManaging
extension ConsolePinManager: PinManaging {}
