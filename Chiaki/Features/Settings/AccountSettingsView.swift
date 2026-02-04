// SPDX-License-Identifier: AGPL-3.0-only
//
// AccountSettingsView.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// View for managing PSN account and settings
//
// @requirement F-027 - UI 层 MVVM 合规重构
// @satisfies AC-091 - AccountSettingsView 使用 ViewModel

import SwiftUI

/// Account settings view using MVVM pattern
/// @requirement F-027 - UI 层 MVVM 合规重构
struct AccountSettingsView: View {
    @State private var viewModel = AccountSettingsViewModel()
    @State private var showingLogin = false
    @State private var showRefreshSuccess = false

    var body: some View {
        List {
            Section {
                if let account = viewModel.account {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(account.onlineId)
                                .font(.headline)
                            Text(String(localized: "psnLogin.accountId \(account.accountId)"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }

                    // Manual refresh button
                    Button {
                        Task {
                            await viewModel.refreshToken()
                            if viewModel.errorMessage == nil {
                                showRefreshSuccess = true
                            }
                        }
                    } label: {
                        HStack {
                            if viewModel.isRefreshing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(String(localized: "psnLogin.refreshToken"))
                        }
                    }
                    .disabled(viewModel.isRefreshing)

                    Button(role: .destructive) {
                        viewModel.signOut()
                    } label: {
                        Text(String(localized: "psnLogin.signOut"))
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "psnLogin.notSignedIn"))
                            .font(.headline)
                        Text(String(localized: "psnLogin.signInDescription"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    Button {
                        showingLogin = true
                    } label: {
                        Text(String(localized: "psnLogin.signIn"))
                    }
                }
            } header: {
                Text(String(localized: "psnLogin.sectionTitle"))
            } footer: {
                if !viewModel.isSignedIn {
                    Text(String(localized: "psnLogin.credentialsNote"))
                }
            }
        }
        .navigationTitle(L10n.Nav.account)
        .sheet(isPresented: $showingLogin) {
            PSNLoginView()
        }
        .alert(String(localized: "psnLogin.refreshFailed"), isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { /* errorMessage cleared on next action */ } }
        )) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .alert(String(localized: "psnLogin.refreshSuccess"), isPresented: $showRefreshSuccess) {
            Button(L10n.Common.ok, role: .cancel) {}
        }
    }
}

#Preview {
    NavigationStack {
        AccountSettingsView()
            .environment(SettingsStore())
            .environment(NavigationManager())
    }
}
