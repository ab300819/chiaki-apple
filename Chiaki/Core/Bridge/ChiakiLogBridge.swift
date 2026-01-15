// SPDX-License-Identifier: AGPL-3.0-only
//
// ChiakiLogBridge.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Bridge between libchiaki's C logging system and Swift Logger

import Foundation

// MARK: - Chiaki Log Bridge

/// Manages the bridge between libchiaki's C logging and Swift's logging system
final class ChiakiLogBridge: @unchecked Sendable {
    /// Singleton instance
    static let shared = ChiakiLogBridge()

    /// The underlying C log structure
    private var chiakiLog: ChiakiLog

    /// Reference to self for C callback context
    private var contextPointer: UnsafeMutableRawPointer?

    private init() {
        chiakiLog = ChiakiLog()
        // Store reference to self for C callback
        contextPointer = Unmanaged.passUnretained(self).toOpaque()
    }

    deinit {
        contextPointer = nil
    }

    /// Initialize the chiaki log with the given level mask
    func initialize(levelMask: ChiakiLogLevelMask = .all) {
        chiaki_log_init(
            &chiakiLog,
            levelMask.rawValue,
            chiakiLogCallback,
            contextPointer
        )
    }

    /// Update the log level mask
    func setLevelMask(_ mask: ChiakiLogLevelMask) {
        chiaki_log_set_level(&chiakiLog, mask.rawValue)
    }

    /// Get a pointer to the underlying ChiakiLog for use with C APIs
    func getLogPointer() -> UnsafeMutablePointer<ChiakiLog> {
        withUnsafeMutablePointer(to: &chiakiLog) { $0 }
    }
}

// MARK: - C Callback

/// C callback function that receives logs from libchiaki and forwards them to Swift Logger
private func chiakiLogCallback(level: ChiakiLogLevel, msg: UnsafePointer<CChar>?, user: UnsafeMutableRawPointer?) {
    guard let msg = msg else { return }

    let message = String(cString: msg)
    // Convert C ChiakiLogLevel to Swift ChiakiLogSeverity
    let severity = ChiakiLogSeverity(rawValue: level.rawValue) ?? .info

    // Forward to Swift logger on main thread
    Task { @MainActor in
        Logger.shared.log(
            level: severity,
            "[chiaki] \(message)",
            file: "libchiaki",
            function: "native",
            line: 0
        )
    }
}
