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
        // Log a message via global function
        let testMessage = "Integration test log message \(UUID().uuidString)"
        logInfo(testMessage)
        
        // Wait for async write in FileLogHandler queue
        let expectation = XCTestExpectation(description: "Wait for log write")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        // Verify file content via shared FileLogHandler if possible, or just check file
        let logFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/chiaki-current.log")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: logFileURL.path), "Log file should exist")
        let content = try String(contentsOf: logFileURL)
        XCTAssertTrue(content.contains(testMessage), "Log file should contain the integration test message")
    }
}
