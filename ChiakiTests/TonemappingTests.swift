// SPDX-License-Identifier: AGPL-3.0-only
//
// TonemappingTests.swift
// ChiakiTests
//

import XCTest
import simd
@testable import Chiaki

final class TonemappingTests: XCTestCase {

    /// [verifies] AC-084
    /// [testcase] UT-030.1
    func testACESBlackPreservation() {
        // [file not found: /Users/mason/.claude/skills/devdocs-dev-workflow/skeleton-examples.md]
        // XCTSkip("T-151: ACES Tone Mapping not implemented")
        let black = simd_float3(0, 0, 0)
        let result = applyACESTonemap(black)
        XCTAssertEqual(result.x, 0, accuracy: 1e-6)
        XCTAssertEqual(result.y, 0, accuracy: 1e-6)
        XCTAssertEqual(result.z, 0, accuracy: 1e-6)
    }

    /// [verifies] AC-084
    /// [testcase] UT-030.2
    func testACESWhiteMapping() {
        // XCTSkip("T-151: ACES Tone Mapping not implemented")
        let white = simd_float3(1, 1, 1)
        let result = applyACESTonemap(white)
        // ACES typically maps 1.0 to something close to 0.8-1.0 depending on the fit
        // For Narkowicz fit, it's roughly 0.82
        XCTAssertGreaterThan(result.x, 0.8)
        XCTAssertLessThanOrEqual(result.x, 1.0)
    }

    /// [verifies] AC-084
    /// [testcase] UT-030.3
    func testACESHighlightCompression() {
        // XCTSkip("T-151: ACES Tone Mapping not implemented")
        let highlight = simd_float3(10, 10, 10)
        let result = applyACESTonemap(highlight)
        XCTAssertLessThanOrEqual(result.x, 1.0)
        XCTAssertGreaterThan(result.x, 0.9) // High brightness should be compressed but stay high
    }

    /// [verifies] AC-084
    /// [testcase] UT-030.4
    func testACESOutputRange() {
        // XCTSkip("T-151: ACES Tone Mapping not implemented")
        let testValues: [Float] = [-1.0, 0.0, 0.5, 1.0, 10.0, 100.0]
        for v in testValues {
            let color = simd_float3(v, v, v)
            let result = applyACESTonemap(color)
            XCTAssertTrue(result.x >= 0.0 && result.x <= 1.0)
            XCTAssertTrue(result.y >= 0.0 && result.y <= 1.0)
            XCTAssertTrue(result.z >= 0.0 && result.z <= 1.0)
        }
    }

    /// [verifies] AC-084
    /// [testcase] UT-030.5
    func testACESMonotonicity() {
        // XCTSkip("T-151: ACES Tone Mapping not implemented")
        for i in 0..<100 {
            let x1 = Float(i) / 10.0
            let x2 = Float(i + 1) / 10.0
            let r1 = applyACESTonemap(simd_float3(x1, x1, x1)).x
            let r2 = applyACESTonemap(simd_float3(x2, x2, x2)).x
            XCTAssertTrue(r2 >= r1, "Tonemapping must be monotonic at x=\(x1)")
        }
    }
}
