// SPDX-License-Identifier: AGPL-3.0-only
//
// AccountSettingsViewModel.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// ViewModel for PSN account settings
//
// @requirement F-027 - UI 层 MVVM 合规重构
// @satisfies AC-091 - AccountSettingsViewModel

import Foundation
import Observation

/// ViewModel for PSN account settings
/// @requirement F-027 - UI 层 MVVM 合规重构
/// @satisfies AC-091 - AccountSettingsViewModel
@Observable
@MainActor
final class AccountSettingsViewModel {
    // MARK: - Published State

    /// Current PSN account (nil if not signed in)
    var account: PSNAccount? {
        psnService.account
    }

    /// Whether user is signed in
    var isSignedIn: Bool {
        psnService.isSignedIn
    }

    /// Whether a refresh operation is in progress
    private(set) var isRefreshing: Bool = false

    /// Error message from last operation
    private(set) var errorMessage: String?

    // MARK: - Dependencies

    private let psnService: PSNServicing

    // MARK: - Initialization

    /// Initialize with PSN service dependency
    /// - Parameter psnService: PSN service implementation (defaults to shared instance)
    init(psnService: PSNServicing? = nil) {
        self.psnService = psnService ?? PSNService.shared
    }

    // MARK: - Actions

    /// Sign out from PSN
    func signOut() {
        errorMessage = nil
        psnService.signOut()
    }

    /// Refresh PSN token
    func refreshToken() async {
        errorMessage = nil
        isRefreshing = true

        do {
            try await psnService.manualRefresh()
        } catch {
            errorMessage = error.localizedDescription
        }

        isRefreshing = false
    }

    /// Get OAuth login URL
    /// - Returns: URL for PSN OAuth login
    func getLoginURL() -> URL {
        psnService.startOAuthLogin()
    }
}
