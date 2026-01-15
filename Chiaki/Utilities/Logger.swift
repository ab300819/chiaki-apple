// SPDX-License-Identifier: AGPL-3.0-only
//
// Logger.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Unified logging system that integrates with both Apple's os.log and libchiaki's logging

import Foundation
import os

// MARK: - Logger Protocol

/// Protocol for logging backends
protocol LogHandler: Sendable {
    func log(level: ChiakiLogSeverity, message: String, file: String, function: String, line: Int)
}

// MARK: - Apple OSLog Handler

/// Logging handler that uses Apple's unified logging system
final class OSLogHandler: LogHandler, @unchecked Sendable {
    private let logger: os.Logger

    init(subsystem: String, category: String) {
        self.logger = os.Logger(subsystem: subsystem, category: category)
    }

    func log(level: ChiakiLogSeverity, message: String, file: String, function: String, line: Int) {
        let fileName = (file as NSString).lastPathComponent
        let formattedMessage = "[\(fileName):\(line)] \(function) - \(message)"

        switch level {
        case .debug:
            logger.debug("\(formattedMessage, privacy: .public)")
        case .verbose:
            logger.trace("\(formattedMessage, privacy: .public)")
        case .info:
            logger.info("\(formattedMessage, privacy: .public)")
        case .warning:
            logger.warning("\(formattedMessage, privacy: .public)")
        case .error:
            logger.error("\(formattedMessage, privacy: .public)")
        }
    }
}

// MARK: - Logger

/// Main application logger that bridges Swift and libchiaki logging
@MainActor
final class Logger {
    static let shared = Logger()

    private var handlers: [LogHandler] = []
    private(set) var levelMask: ChiakiLogLevelMask

    private init() {
        #if DEBUG
        self.levelMask = .all
        #else
        self.levelMask = .production
        #endif

        // Add default OSLog handler
        let osLogHandler = OSLogHandler(subsystem: "ltd.hotter.chiaki", category: "App")
        handlers.append(osLogHandler)
    }

    func addHandler(_ handler: LogHandler) {
        handlers.append(handler)
    }

    func setLevelMask(_ mask: ChiakiLogLevelMask) {
        self.levelMask = mask
    }

    private func shouldLog(level: ChiakiLogSeverity) -> Bool {
        ChiakiLogLevelMask(rawValue: level.rawValue).isSubset(of: levelMask)
    }

    func log(
        level: ChiakiLogSeverity,
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard shouldLog(level: level) else { return }
        let msg = message()
        for handler in handlers {
            handler.log(level: level, message: msg, file: file, function: function, line: line)
        }
    }

    // Convenience methods
    func debug(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .debug, message(), file: file, function: function, line: line)
    }

    func verbose(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .verbose, message(), file: file, function: function, line: line)
    }

    func info(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .info, message(), file: file, function: function, line: line)
    }

    func warning(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .warning, message(), file: file, function: function, line: line)
    }

    func error(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .error, message(), file: file, function: function, line: line)
    }
}

// MARK: - Global Logging Functions

/// Log a debug message
func logDebug(
    _ message: @autoclosure () -> String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    let msg = message()
    Task { @MainActor in
        Logger.shared.debug(msg, file: file, function: function, line: line)
    }
}

/// Log a verbose message
func logVerbose(
    _ message: @autoclosure () -> String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    let msg = message()
    Task { @MainActor in
        Logger.shared.verbose(msg, file: file, function: function, line: line)
    }
}

/// Log an info message
func logInfo(
    _ message: @autoclosure () -> String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    let msg = message()
    Task { @MainActor in
        Logger.shared.info(msg, file: file, function: function, line: line)
    }
}

/// Log a warning message
func logWarning(
    _ message: @autoclosure () -> String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    let msg = message()
    Task { @MainActor in
        Logger.shared.warning(msg, file: file, function: function, line: line)
    }
}

/// Log an error message
func logError(
    _ message: @autoclosure () -> String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    let msg = message()
    Task { @MainActor in
        Logger.shared.error(msg, file: file, function: function, line: line)
    }
}
