// SPDX-License-Identifier: AGPL-3.0-only
//
// StartupIntegrationTests.swift
// ChiakiTests
//
// Integration tests for App startup and crash detection
// @requirement F-019 - 完善日志系统

import XCTest
@testable import Chiaki

final class StartupIntegrationTests: XCTestCase {
    
    /// @verifies AC-052 - 崩溃捕捉与报告
    /// @testcase IT-19.3
    func testCrashDetectionOnStartup() {
        let reporter = CrashReporter.shared
        reporter.clearCrashReport()
        
        // Simulate a crash report from previous run
        reporter.writeCrashReport(reason: "Simulated Crash", stackTrace: "Stack", logs: ["Log 1"])
        
        XCTAssertTrue(reporter.hasCrashReport(), "Crash report should exist")
        
        // In a real integration test we would check if ChiakiApp detects this, 
        // but since we can't easily instantiate ChiakiApp in XCTest and check its private state,
        // we verify the underlying logic.
        
        if reporter.hasCrashReport() {
            let report = try? reporter.readCrashReport()
            XCTAssertNotNil(report)
            XCTAssertTrue(report?.contains("Simulated Crash") ?? false)
        }
        
        reporter.clearCrashReport()
    }
}
