// SPDX-License-Identifier: AGPL-3.0-only
//
// CrashReporterTests.swift
// ChiakiTests
//
// Tests for CrashReporter
// @requirement F-019 - 完善日志系统

import XCTest
@testable import Chiaki

final class CrashReporterTests: XCTestCase {
    let reporter = CrashReporter.shared
    
    override func setUp() {
        super.setUp()
        reporter.clearCrashReport()
    }
    
    /// @verifies AC-052 - 崩溃捕捉与报告
    /// @testcase UT-19.9
    func testCrashReportWriting() throws {
        let reason = "Manual Test Crash"
        let stackTrace = "Frame 0: testCrashReportWriting"
        let logs = ["Log 1", "Log 2"]
        
        reporter.writeCrashReport(reason: reason, stackTrace: stackTrace, logs: logs)
        
        XCTAssertTrue(reporter.hasCrashReport())
        let content = try reporter.readCrashReport()
        XCTAssertTrue(content.contains(reason))
        XCTAssertTrue(content.contains(stackTrace))
        XCTAssertTrue(content.contains("Log 1"))
    }
    
    /// @verifies AC-052 - 崩溃捕捉与报告
    /// @testcase UT-19.10
    func testCrashReportReading() throws {
        XCTAssertFalse(reporter.hasCrashReport())
        XCTAssertThrowsError(try reporter.readCrashReport())
    }
    
    /// @verifies AC-052 - 崩溃捕捉与报告
    /// @testcase UT-19.11
    func testCrashReportCleanup() {
        reporter.writeCrashReport(reason: "Test", stackTrace: "", logs: [])
        XCTAssertTrue(reporter.hasCrashReport())
        reporter.clearCrashReport()
        XCTAssertFalse(reporter.hasCrashReport())
    }
}
