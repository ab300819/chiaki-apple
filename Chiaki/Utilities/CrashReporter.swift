// SPDX-License-Identifier: AGPL-3.0-only
//
// CrashReporter.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Minimal crash reporting system to capture signals and uncaught exceptions
// @requirement F-019 - 完善日志系统

import Foundation

/// A lightweight reporter that captures app crashes and saves them to a file
/// @requirement F-019 - 完善日志系统
/// @satisfies AC-052 - 崩溃捕捉与报告
final class CrashReporter: Sendable {
    static let shared = CrashReporter()
    
    private let fileManager = FileManager.default
    private let crashLogURL: URL
    
    private init() {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let logsDir = paths[0].appendingPathComponent("Logs")
        self.crashLogURL = logsDir.appendingPathComponent("crash_report.log")
    }
    
    /// Sets up the crash reporter by registering signal handlers and uncaught exception handler
    /// @satisfies AC-052 - 崩溃捕捉与报告
    func setup() {
        NSSetUncaughtExceptionHandler { exception in
            CrashReporter.shared.handleException(exception)
        }
        
        signal(SIGABRT) { sig in CrashReporter.shared.handleSignal(sig) }
        signal(SIGILL) { sig in CrashReporter.shared.handleSignal(sig) }
        signal(SIGSEGV) { sig in CrashReporter.shared.handleSignal(sig) }
        signal(SIGFPE) { sig in CrashReporter.shared.handleSignal(sig) }
        signal(SIGBUS) { sig in CrashReporter.shared.handleSignal(sig) }
        signal(SIGPIPE, SIG_IGN)
    }
    
    /// Checks if a crash report exists from a previous run
    /// @satisfies AC-052 - 崩溃捕捉与报告
    func hasCrashReport() -> Bool {
        return fileManager.fileExists(atPath: crashLogURL.path)
    }
    
    /// Reads the crash report content
    func readCrashReport() throws -> String {
        guard hasCrashReport() else {
            throw NSError(domain: "CrashReporter", code: 2, userInfo: [NSLocalizedDescriptionKey: "No crash report found"])
        }
        return try String(contentsOf: crashLogURL, encoding: .utf8)
    }
    
    /// Clears the crash report
    func clearCrashReport() {
        try? fileManager.removeItem(at: crashLogURL)
    }
    
    /// Writes a crash report manually (used for testing or manual triggers)
    /// @satisfies AC-052 - 崩溃捕捉与报告
    func writeCrashReport(reason: String, stackTrace: String, logs: [String]) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        var report = """
        --- CHIAKI CRASH REPORT ---
        Timestamp: \(timestamp)
        Reason: \(reason)
        
        --- STACK TRACE ---
        \(stackTrace)
        
        --- RECENT LOGS ---
        \(logs.joined(separator: "\n"))
        ---------------------------
        """
        
        let logsDir = crashLogURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: logsDir.path) {
            try? fileManager.createDirectory(at: logsDir, withIntermediateDirectories: true)
        }
        
        try? report.write(to: crashLogURL, atomically: true, encoding: .utf8)
    }
    
    func handleException(_ exception: NSException) {
        let stack = exception.callStackSymbols.joined(separator: "\n")
        let reason = "Uncaught Exception: \(exception.name.rawValue) - \(exception.reason ?? "No reason")"
        let logs = getRecentLogs()
        writeCrashReport(reason: reason, stackTrace: stack, logs: logs)
    }
    
    func handleSignal(_ sig: Int32) {
        let reason = "Signal: \(sig)"
        let stack = Thread.callStackSymbols.joined(separator: "\n")
        let logs = getRecentLogs()
        writeCrashReport(reason: reason, stackTrace: stack, logs: logs)
        
        exit(sig)
    }
    
    private func getRecentLogs() -> [String] {
        let history = Logger.shared.getHistory()
        return history.suffix(50).map { "[\($0.level.symbol)] [\($0.category)] \($0.message)" }
    }
}
