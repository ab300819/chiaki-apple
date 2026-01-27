// SPDX-License-Identifier: AGPL-3.0-only
//
// AccountSettingsView.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// View for managing PSN account and settings

import SwiftUI

struct AccountSettingsView: View {
    @State private var psnService = PSNService.shared
    @State private var showingLogin = false
    @State private var isRefreshing = false
    @State private var refreshError: String?
    @State private var showRefreshSuccess = false

    var body: some View {
        List {
            Section {
                if let account = psnService.account {
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

                    // Token status
                    if let expirationDate = psnService.tokenExpirationDate {
                        HStack {
                            Text(String(localized: "psnLogin.tokenExpires"))
                            Spacer()
                            if psnService.isTokenExpired {
                                Text(String(localized: "psnLogin.tokenExpired"))
                                    .foregroundStyle(.red)
                            } else {
                                Text(expirationDate.formatted(date: .abbreviated, time: .shortened))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.caption)
                    }

                    // Manual refresh button
                    Button {
                        Task {
                            await refreshToken()
                        }
                    } label: {
                        HStack {
                            if isRefreshing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(String(localized: "psnLogin.refreshToken"))
                        }
                    }
                    .disabled(isRefreshing)

                    Button(role: .destructive) {
                        psnService.signOut()
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
                if !psnService.isAuthenticated {
                    Text(String(localized: "psnLogin.credentialsNote"))
                }
            }
        }
        .navigationTitle(L10n.Nav.account)
        .sheet(isPresented: $showingLogin) {
            PSNLoginView()
        }
        .alert(String(localized: "psnLogin.refreshFailed"), isPresented: .init(
            get: { refreshError != nil },
            set: { if !$0 { refreshError = nil } }
        )) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            if let error = refreshError {
                Text(error)
            }
        }
        .alert(String(localized: "psnLogin.refreshSuccess"), isPresented: $showRefreshSuccess) {
            Button(L10n.Common.ok, role: .cancel) {}
        }
    }

    private func refreshToken() async {
        isRefreshing = true
        refreshError = nil

        do {
            try await psnService.manualRefresh()
            showRefreshSuccess = true
        } catch {
            refreshError = error.localizedDescription
        }

        isRefreshing = false
    }
}

#Preview {
    NavigationStack {
        AccountSettingsView()
            .environment(SettingsStore())
            .environment(NavigationManager())
    }
}
