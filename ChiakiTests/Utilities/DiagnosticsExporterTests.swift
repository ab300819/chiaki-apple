// SPDX-License-Identifier: AGPL-3.0-only
//
// DiagnosticsExporterTests.swift
// ChiakiTests
//
// Tests for DiagnosticsExporter
// @requirement F-019 - 完善日志系统

import XCTest
@testable import Chiaki

final class DiagnosticsExporterTests: XCTestCase {
    let exporter = DiagnosticsExporter()
    
    /// @verifies AC-053 - 诊断包数据脱敏
    /// @testcase UT-19.5
    func testIPAnonymization() {
        let ip = "192.168.1.100"
        let anonymized = exporter.anonymizeIP(ip)
        XCTAssertEqual(anonymized, "192.168.xxx.xxx")
    }
    
    /// @verifies AC-053 - 诊断包数据脱敏
    /// @testcase UT-19.6
    func testTokenAnonymization() {
        let token = "abcdefghijklmnop"
        let anonymized = exporter.anonymizeToken(token)
        XCTAssertTrue(anonymized.hasPrefix("abcdefgh"))
        XCTAssertTrue(anonymized.hasSuffix("..."))
        XCTAssertEqual(anonymized.count, 11) // 8 + 3
    }
    
    /// @verifies AC-053 - 诊断包数据脱敏
    /// @testcase UT-19.7
    func testUserIDAnonymization() {
        let userID = "1234567890"
        let anonymized = exporter.anonymizeUserID(userID)
        XCTAssertNotEqual(userID, anonymized)
        XCTAssertEqual(anonymized.count, 16)
    }
    
    /// @verifies AC-053 - 诊断包数据脱敏
    /// @testcase UT-19.8
    func testMACAnonymization() {
        let mac = "AA:BB:CC:DD:EE:FF"
        let anonymized = exporter.anonymizeMAC(mac)
        XCTAssertEqual(anonymized, "AA:BB:CC:xx:xx:xx")
    }
    
    /// @verifies AC-051 - 诊断包生成
    /// @testcase IT-19.2
    func testExport() async throws {
        let zipURL = try await exporter.export()
        XCTAssertTrue(FileManager.default.fileExists(atPath: zipURL.path))
        XCTAssertTrue(zipURL.lastPathComponent.hasSuffix(".zip"))
        
        try? FileManager.default.removeItem(at: zipURL)
    }
}
