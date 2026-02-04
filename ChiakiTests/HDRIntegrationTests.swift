// SPDX-License-Identifier: AGPL-3.0-only
//
// HDRIntegrationTests.swift
// ChiakiTests
//

import XCTest
import MetalKit
@testable import Chiaki

final class HDRIntegrationTests: XCTestCase {
    
    var renderer: MetalVideoRenderer!
    
    override func setUp() {
        super.setUp()
        renderer = MetalVideoRenderer()
    }
    
    override func tearDown() {
        renderer = nil
        super.tearDown()
    }
    
    /// [verifies] AC-081, AC-082
    /// [testcase] IT-011.2
    func testUniformExpansionAlignment() {
        // Verify that setting properties updates the internal uniforms
        // We can't access private 'uniforms' directly, but we can verify the public properties
        
        renderer.edrHeadroom = 3.5
        XCTAssertEqual(renderer.edrHeadroom, 3.5)
        
        renderer.tonemapMode = .aces
        XCTAssertEqual(renderer.tonemapMode, .aces)
        
        // Test clamping
        renderer.edrHeadroom = 0.5
        XCTAssertEqual(renderer.edrHeadroom, 1.0, "EDR Headroom should be clamped to minimum 1.0")
    }
    
    /// [verifies] AC-088
    /// [testcase] UT-034.2
    func testHDRConfigurationSync() {
        let config = HDRConfiguration(
            enabled: true,
            edrIntensity: 1.5,
            colorSpace: .bt2020,
            colorRange: .full,
            tonemapMode: .aces,
            gamutMappingEnabled: true
        )
        
        renderer.hdrConfiguration = config
        
        // Verify individual properties synced to uniforms via the getters
        XCTAssertEqual(renderer.tonemapMode, .aces)
        
        // Note: colorSpace and colorRange don't have direct public getters in the current MetalVideoRenderer
        // but they are updated in hdrConfiguration.didSet.
        XCTAssertEqual(renderer.hdrConfiguration.colorSpace, .bt2020)
    }
}
