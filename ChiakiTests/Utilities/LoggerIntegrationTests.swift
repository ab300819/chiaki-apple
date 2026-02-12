// SPDX-License-Identifier: AGPL-3.0-only
//
// LoggerIntegrationTests.swift
// ChiakiTests
//
// Integration tests for Logger and FileLogHandler
// @requirement F-019 - 完善日志系统

import XCTest
@testable import Chiaki

final class LoggerIntegrationTests: XCTestCase {

    private func waitForContent(_ url: URL, containing token: String, timeout: TimeInterval = 3.0) -> String {
        let deadline = Date().addingTimeInterval(timeout)
        var latestContent = ""

        while Date() < deadline {
            latestContent = (try? String(contentsOf: url)) ?? ""
            if latestContent.contains(token) {
                return latestContent
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        return latestContent
    }
    
    /// @verifies AC-049 - 日志写入 Documents/Logs
    /// @testcase UT-19.4
    @MainActor
    func testLoggerIncludesFileLogHandler() {
        XCTAssertNotNil(Logger.shared.fileLogHandler, "Logger should automatically include FileLogHandler")
    }
    
    /// @verifies AC-049 - 日志写入 Documents/Logs
    /// @testcase IT-19.1
    @MainActor
    func testLoggerIntegration() throws {
        let testMessage = "Integration test log message \(UUID().uuidString)"
        Logger.shared.info(testMessage)
        Logger.shared.fileLogHandler?.flush()
        
        // Verify file content via shared FileLogHandler if possible, or just check file
        let logFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/chiaki-current.log")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: logFileURL.path), "Log file should exist")
        let content = waitForContent(logFileURL, containing: testMessage)
        XCTAssertTrue(content.contains(testMessage), "Log file should contain the integration test message")
    }
}
