// SPDX-License-Identifier: AGPL-3.0-only
//
// PSNServicingTests.swift
// ChiakiTests
//
// @verifies AC-095 - 协议抽象

import Foundation
import Testing
@testable import Chiaki

@Suite("PSNServicing Tests")
struct PSNServicingTests {
    private struct AuthConsumer {
        let service: PSNServicing
    }

    /**
     * @verifies AC-095 - 协议抽象
     * @testcase UT-040.1
     */
    @Test("PSNService conforms to PSNServicing")
    func testPSNServiceConformsToProtocol() {
        let service: PSNServicing = PSNService.shared
        #expect(service is PSNServicing)
    }

    /**
     * @verifies AC-095 - 协议抽象
     * @testcase UT-040.2
     */
    @Test("Mock PSN service can be injected")
    func testMockCanBeInjected() {
        let mock = MockPSNService()
        let consumer = AuthConsumer(service: mock)
        #expect(consumer.service is MockPSNService)
    }
}

private final class MockPSNService: PSNServicing {
    var account: PSNAccount?
    var isSignedIn: Bool = false
    var authState: PSNAuthState = .signedOut
    var signOutCalled = false
    var refreshCalled = false

    func signOut() {
        signOutCalled = true
        isSignedIn = false
    }

    func manualRefresh() async throws {
        refreshCalled = true
    }

    func startOAuthLogin() -> URL {
        URL(string: "https://example.com/login")!
    }
}
