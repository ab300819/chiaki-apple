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
    
    /// @verifies AC-049 - 日志写入 Documents/Logs
    /// @testcase UT-19.1
    func testLogWriting() throws {
        let handler = try FileLogHandler()
        let testMessage = "Test log message"
        handler.log(level: .info, message: testMessage, category: "TestCat", file: "TestFile.swift", function: "testFunc", line: 42)
        
        let expectation = XCTestExpectation(description: "Wait for log write")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        let logFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/chiaki-current.log")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: logFileURL.path), "Log file should exist")
        let content = try String(contentsOf: logFileURL)
        XCTAssertTrue(content.contains(testMessage), "Log file should contain the test message")
        XCTAssertTrue(content.contains("[I]"), "Log file should contain level symbol")
        XCTAssertTrue(content.contains("TestFile.swift:42"), "Log file should contain file info")
    }
    
    /// @verifies AC-050 - 日志文件轮换与清理
    /// @testcase UT-19.2
    func testLogRotation() throws {
        let fileManager = FileManager.default
        let logDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs")
        let currentLogURL = logDirectory.appendingPathComponent("chiaki-current.log")
        
        try? fileManager.removeItem(at: logDirectory)
        try fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        
        let largeData = Data(repeating: 0, count: 5 * 1024 * 1024 + 100)
        try largeData.write(to: currentLogURL)
        
        let handler = try FileLogHandler()
        handler.log(level: .info, message: "Trigger rotation", category: "Test", file: "File.swift", function: "func", line: 1)
        
        let expectation = XCTestExpectation(description: "Wait for rotation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
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
        let logDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs")
        
        try? fileManager.removeItem(at: logDirectory)
        try fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        
        for i in 1...10 {
            let fileURL = logDirectory.appendingPathComponent("chiaki-old-\(i).log")
            try "Log \(i)".write(to: fileURL, atomically: true, encoding: .utf8)
            Thread.sleep(forTimeInterval: 0.01)
        }
        
        let currentLogURL = logDirectory.appendingPathComponent("chiaki-current.log")
        let largeData = Data(repeating: 0, count: 5 * 1024 * 1024 + 100)
        try largeData.write(to: currentLogURL)
        
        let handler = try FileLogHandler()
        handler.log(level: .info, message: "Trigger cleanup", category: "Test", file: "File.swift", function: "func", line: 1)
        
        let expectation = XCTestExpectation(description: "Wait for cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        let files = try fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: nil)
        let archivedLogs = files.filter { $0.lastPathComponent.hasPrefix("chiaki-") && $0.lastPathComponent != "chiaki-current.log" }
        
        XCTAssertEqual(archivedLogs.count, 7, "Should only keep 7 archived logs")
    }
}
