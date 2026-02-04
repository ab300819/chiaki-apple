// SPDX-License-Identifier: AGPL-3.0-only
//
// AccountSettingsViewModelTests.swift
// ChiakiTests
//
// @requirement F-027 - UI 层 MVVM 合规重构
// @verifies AC-091 - AccountSettingsViewModel

import Foundation
import Testing
@testable import Chiaki

@Suite("AccountSettingsViewModel Tests")
@MainActor
struct AccountSettingsViewModelTests {

    // MARK: - Mock

    private final class MockPSNService: PSNServicing {
        var account: PSNAccount?
        var isSignedIn: Bool = false
        var authState: PSNAuthState = .signedOut

        var signOutCalled = false
        var refreshCalled = false
        var refreshShouldThrow = false

        func signOut() {
            signOutCalled = true
            isSignedIn = false
            authState = .signedOut
            account = nil
        }

        func manualRefresh() async throws {
            refreshCalled = true
            if refreshShouldThrow {
                throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Refresh failed"])
            }
        }

        func startOAuthLogin() -> URL {
            URL(string: "https://example.com/oauth")!
        }
    }

    // MARK: - UT-036.1: Dependency Injection

    /**
     * @verifies AC-091 - AccountSettingsViewModel
     * @testcase UT-036.1
     */
    @Test("ViewModel accepts PSNServicing via constructor")
    func testDependencyInjection() {
        let mock = MockPSNService()
        let viewModel = AccountSettingsViewModel(psnService: mock)
        #expect(viewModel != nil)
    }

    // MARK: - UT-036.2: State Exposure

    /**
     * @verifies AC-091 - AccountSettingsViewModel
     * @testcase UT-036.2
     */
    @Test("ViewModel exposes account state from service")
    func testAccountStateExposure() {
        let mock = MockPSNService()
        mock.isSignedIn = true
        mock.authState = .signedIn

        let viewModel = AccountSettingsViewModel(psnService: mock)

        #expect(viewModel.isSignedIn == true)
    }

    // MARK: - UT-036.3: Sign Out

    /**
     * @verifies AC-091 - AccountSettingsViewModel
     * @testcase UT-036.3
     */
    @Test("signOut delegates to service")
    func testSignOut() {
        let mock = MockPSNService()
        mock.isSignedIn = true

        let viewModel = AccountSettingsViewModel(psnService: mock)
        viewModel.signOut()

        #expect(mock.signOutCalled == true)
    }

    // MARK: - UT-036.4: Refresh Token

    /**
     * @verifies AC-091 - AccountSettingsViewModel
     * @testcase UT-036.4
     */
    @Test("refreshToken calls service and updates isRefreshing")
    func testRefreshToken() async {
        let mock = MockPSNService()
        let viewModel = AccountSettingsViewModel(psnService: mock)

        await viewModel.refreshToken()

        #expect(mock.refreshCalled == true)
        #expect(viewModel.isRefreshing == false)
    }

    // MARK: - UT-036.5: Error Handling

    /**
     * @verifies AC-091 - AccountSettingsViewModel
     * @testcase UT-036.5
     */
    @Test("refreshToken sets errorMessage on failure")
    func testRefreshTokenError() async {
        let mock = MockPSNService()
        mock.refreshShouldThrow = true

        let viewModel = AccountSettingsViewModel(psnService: mock)
        await viewModel.refreshToken()

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isRefreshing == false)
    }

    // MARK: - Login URL

    /**
     * @verifies AC-091 - AccountSettingsViewModel
     * @testcase UT-036.6
     */
    @Test("getLoginURL returns URL from service")
    func testGetLoginURL() {
        let mock = MockPSNService()
        let viewModel = AccountSettingsViewModel(psnService: mock)

        let url = viewModel.getLoginURL()

        #expect(url.absoluteString == "https://example.com/oauth")
    }
}
