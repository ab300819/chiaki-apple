// SPDX-License-Identifier: AGPL-3.0-only
//
// AccountSettingsView.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// View for managing PSN account and settings

import SwiftUI

struct AccountSettingsView: View {
    @StateObject private var psnService = PSNService.shared
    @State private var showingLogin = false
    
    var body: some View {
        List {
            Section {
                if let account = psnService.account {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(account.onlineId)
                                .font(.headline)
                            Text("Account ID: \(account.accountId)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    
                    Button(role: .destructive) {
                        psnService.signOut()
                    } label: {
                        Text("Sign Out")
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Not Signed In")
                            .font(.headline)
                        Text("Sign in to PSN to easily register your consoles and enable remote play over the internet.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    Button {
                        showingLogin = true
                    } label: {
                        Text("Sign In to PSN")
                    }
                }
            } header: {
                Text("PlayStation Network")
            } footer: {
                if !psnService.isAuthenticated {
                    Text("Your credentials are stored securely in the system Keychain.")
                }
            }
        }
        .navigationTitle("Account Settings")
        .sheet(isPresented: $showingLogin) {
            PSNLoginView()
        }
    }
}

#Preview {
    NavigationView {
        AccountSettingsView()
    }
}
