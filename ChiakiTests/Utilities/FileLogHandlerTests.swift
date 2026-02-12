// SPDX-License-Identifier: AGPL-3.0-only
//
// FileLogHandlerTests.swift
// ChiakiTests
//
// Tests for FileLogHandler
// @requirement F-019 - 完善日志系统

import XCTest
@testable import Chiaki

final class FileLogHandlerTests: XCTestCase {

    private func makeIsolatedLogDirectory() throws -> URL {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("ChiakiTests-Logs", isDirectory: true)
        let dir = base.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func waitForFileContains(_ url: URL, expected: [String], timeout: TimeInterval = 2.0) -> String {
        let deadline = Date().addingTimeInterval(timeout)
        var latestContent = ""

        while Date() < deadline {
            latestContent = (try? String(contentsOf: url)) ?? ""
            if !latestContent.isEmpty && expected.allSatisfy({ latestContent.contains($0) }) {
                return latestContent
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        return latestContent
    }
    
    /// @verifies AC-049 - 日志写入 Documents/Logs
    /// @testcase UT-19.1
    func testLogWriting() throws {
        let logDirectory = try makeIsolatedLogDirectory()
        let handler = try FileLogHandler(logDirectory: logDirectory)
        defer { try? FileManager.default.removeItem(at: logDirectory) }

        let testMessage = "Test log message"
        handler.log(level: .info, message: testMessage, category: "TestCat", file: "TestFile.swift", function: "testFunc", line: 42)
        handler.flush()
        
        let logFileURL = logDirectory.appendingPathComponent("chiaki-current.log")

        XCTAssertTrue(FileManager.default.fileExists(atPath: logFileURL.path), "Log file should exist")
        let content = waitForFileContains(logFileURL, expected: [testMessage, "[I]", "TestFile.swift:42"])
        XCTAssertTrue(content.contains(testMessage), "Log file should contain the test message")
        XCTAssertTrue(content.contains("[I]"), "Log file should contain level symbol")
        XCTAssertTrue(content.contains("TestFile.swift:42"), "Log file should contain file info")
    }
    
    /// @verifies AC-050 - 日志文件轮换与清理
    /// @testcase UT-19.2
    func testLogRotation() throws {
        let fileManager = FileManager.default
        let logDirectory = try makeIsolatedLogDirectory()
        defer { try? fileManager.removeItem(at: logDirectory) }

        let currentLogURL = logDirectory.appendingPathComponent("chiaki-current.log")

        let largeData = Data(repeating: 0, count: 5 * 1024 * 1024 + 100)
        try largeData.write(to: currentLogURL)
        
        let handler = try FileLogHandler(logDirectory: logDirectory)
        handler.log(level: .info, message: "Trigger rotation", category: "Test", file: "File.swift", function: "func", line: 1)
        handler.flush()
        
        let currentAttributes = try fileManager.attributesOfItem(atPath: currentLogURL.path)
        let currentSize = currentAttributes[.size] as? Int64 ?? 0
        XCTAssertLessThan(currentSize, 1024, "Current log should be reset and small")
        
        let files = try fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: nil)
        let archivedLogs = files.filter { $0.lastPathComponent.hasPrefix("chiaki-") && $0.lastPathComponent != "chiaki-current.log" }
        XCTAssertEqual(archivedLogs.count, 1, "Should have one archived log")
    }
    
    /// @verifies AC-050 - 日志文件轮换与清理
    /// @testcase UT-19.3
    func testLogCleanup() throws {
        let fileManager = FileManager.default
        let logDirectory = try makeIsolatedLogDirectory()
        defer { try? fileManager.removeItem(at: logDirectory) }

        for i in 1...10 {
            let fileURL = logDirectory.appendingPathComponent("chiaki-old-\(i).log")
            try "Log \(i)".write(to: fileURL, atomically: true, encoding: .utf8)
            Thread.sleep(forTimeInterval: 0.01)
        }
        
        let currentLogURL = logDirectory.appendingPathComponent("chiaki-current.log")
        let largeData = Data(repeating: 0, count: 5 * 1024 * 1024 + 100)
        try largeData.write(to: currentLogURL)
        
        let handler = try FileLogHandler(logDirectory: logDirectory)
        handler.log(level: .info, message: "Trigger cleanup", category: "Test", file: "File.swift", function: "func", line: 1)
        handler.flush()
        
        let files = try fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: nil)
        let archivedLogs = files.filter { $0.lastPathComponent.hasPrefix("chiaki-") && $0.lastPathComponent != "chiaki-current.log" }
        
        XCTAssertEqual(archivedLogs.count, 7, "Should only keep 7 archived logs")
    }
}
