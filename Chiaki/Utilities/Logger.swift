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
    func log(level: ChiakiLogSeverity, message: String, category: String, file: String, function: String, line: Int)
}

// MARK: - Apple OSLog Handler

/// Logging handler that uses Apple's unified logging system
final class OSLogHandler: LogHandler, @unchecked Sendable {
    private let logger: os.Logger

    init(subsystem: String, category: String) {
        self.logger = os.Logger(subsystem: subsystem, category: category)
    }

    func log(level: ChiakiLogSeverity, message: String, category: String, file: String, function: String, line: Int) {
        let fileName = (file as NSString).lastPathComponent
        let formattedMessage = "[\(category)] [\(fileName):\(line)] \(function) - \(message)"

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
final class Logger: Sendable {
    static let shared = Logger()

    private var handlers: [LogHandler]
    private(set) var levelMask: ChiakiLogLevelMask
    
    var fileLogHandler: FileLogHandler? {
        handlers.compactMap { $0 as? FileLogHandler }.first
    }
    
    // Log history for in-app viewer
    private(set) var logHistory: [LogEntry] = []
    private let maxHistory = 1000
    private let historyLock = NSLock()

    struct LogEntry: Identifiable, Sendable {
        let id = UUID()
        let timestamp = Date()
        let level: ChiakiLogSeverity
        let message: String
        let category: String
    }

    private init() {
        #if DEBUG
        self.levelMask = .all
        #else
        self.levelMask = .production
        #endif

        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
            let osLogHandler = OSLogHandler(subsystem: "ltd.hotter.chiaki", category: "App")
            var initialHandlers: [LogHandler] = [osLogHandler]
            
            do {
                let fileLogHandler = try FileLogHandler()
                initialHandlers.append(fileLogHandler)
            } catch {
                print("Failed to initialize FileLogHandler: \(error)")
            }
            
            self.handlers = initialHandlers
        } else {
            self.handlers = []
        }
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
        category: String = "App",
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard shouldLog(level: level) else { return }
        let msg = message()
        
        // Add to history
        let entry = LogEntry(level: level, message: msg, category: category)
        historyLock.lock()
        logHistory.append(entry)
        if logHistory.count > maxHistory {
            logHistory.removeFirst()
        }
        historyLock.unlock()

        for handler in handlers {
            handler.log(level: level, message: msg, category: category, file: file, function: function, line: line)
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

// MARK: - Category Loggers

/// Category-specific loggers for different subsystems
extension Logger {
    /// Logger for session/streaming related events
    static let session = CategoryLogger(category: "Session")

    /// Logger for discovery related events
    static let discovery = CategoryLogger(category: "Discovery")

    /// Logger for storage related events
    static let storage = CategoryLogger(category: "Storage")

    /// Logger for video related events
    static let video = CategoryLogger(category: "Video")

    /// Logger for audio related events
    static let audio = CategoryLogger(category: "Audio")

    /// Logger for controller input events
    static let controller = CategoryLogger(category: "Controller")

    /// Logger for network events
    static let network = CategoryLogger(category: "Network")

    /// Logger for PSN authentication events
    static let psn = CategoryLogger(category: "PSN")
}

/// A category-specific logger that uses OSLog directly
struct CategoryLogger: Sendable {
    private let logger: os.Logger

    init(category: String) {
        self.logger = os.Logger(subsystem: "ltd.hotter.chiaki", category: category)
    }

    func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }

    func trace(_ message: String) {
        logger.trace("\(message, privacy: .public)")
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
