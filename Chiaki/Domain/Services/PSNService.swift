// SPDX-License-Identifier: AGPL-3.0-only
//
// PSNService.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Service for handling PSN authentication and user profile fetching

import Foundation
import Combine

/// Information about a PSN account
struct PSNAccount: Codable, Equatable {
    let onlineId: String
    let accountId: String
}

/// PSN Authentication tokens
struct PSNTokens: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let expirationDate: Date
    
    var isExpired: Bool {
        // Expired if current date is past expiration date (with 5 min buffer)
        return Date().addingTimeInterval(300) >= expirationDate
    }
}

/// Service for PSN login and token management
@MainActor
final class PSNService: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var account: PSNAccount?
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var isAuthenticating: Bool = false
    
    // MARK: - Constants
    
    private let clientId = "09515159-7237-43f2-bcdd-aa7589582e4f"
    private let redirectUri = "com.playstation.PlayStationApp://redirect"
    private let scope = "psn:mobile.v2.core psn:clientapp"
    
    private let authUrl = "https://ca.account.sony.com/api/authz/v3/oauth/authorize"
    private let tokenUrl = "https://ca.account.sony.com/api/authz/v3/oauth/token"
    private let profileUrl = "https://m.np.playstation.com/api/userProfile/v1/users/me/profile"
    
    private let keychainAccountKey = "psn.account"
    private let keychainTokensKey = "psn.tokens"
    
    // MARK: - Singleton
    
    static let shared = PSNService()
    
    // MARK: - Initialization
    
    private init() {
        loadFromKeychain()
    }
    
    // MARK: - Public Methods
    
    /// Get the login URL for the web view
    func getLoginUrl() -> URL {
        var components = URLComponents(string: authUrl)!
        components.queryItems = [
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope)
        ]
        return components.url!
    }
    
    /// Handle the authorization code from the redirect
    func handleAuthorizationCode(_ code: String) async throws {
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        // Exchange code for tokens
        let tokens = try await exchangeCodeForTokens(code)
        
        // Save tokens
        try saveTokens(tokens)
        
        // Fetch profile
        let profile = try await fetchProfile(accessToken: tokens.accessToken)
        let account = PSNAccount(onlineId: profile.onlineId, accountId: profile.accountId)
        
        // Save account info
        try saveAccount(account)
        
        self.tokens = tokens
        self.account = account
        self.isAuthenticated = true
        
        Logger.psn.info("Successfully authenticated with PSN as \(account.onlineId)")
    }
    
    /// Sign out and clear all credentials
    func signOut() {
        try? KeychainManager.shared.delete(key: keychainAccountKey)
        try? KeychainManager.shared.delete(key: keychainTokensKey)
        
        self.account = nil
        self.tokens = nil
        self.isAuthenticated = false
        
        Logger.psn.info("Signed out from PSN")
    }
    
    /// Refresh the access token if needed
    func refreshIfNeeded() async throws {
        guard let tokens = self.tokens else { return }
        
        if tokens.isExpired {
            Logger.psn.info("PSN access token expired or expiring soon, refreshing...")
            try await refreshTokens()
        }
    }
    
    /// Get valid access token (refreshes if needed)
    func getValidAccessToken() async throws -> String {
        try await refreshIfNeeded()
        guard let accessToken = tokens?.accessToken else {
            throw NSError(domain: "PSNService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        return accessToken
    }
    
    // MARK: - Private Methods
    
    private var tokens: PSNTokens?
    
    private func loadFromKeychain() {
        do {
            if let accountData = try? KeychainManager.shared.load(key: keychainAccountKey) {
                self.account = try JSONDecoder().decode(PSNAccount.self, from: accountData)
            }
            
            if let tokensData = try? KeychainManager.shared.load(key: keychainTokensKey) {
                let tokens = try JSONDecoder().decode(PSNTokens.self, from: tokensData)
                self.tokens = tokens
                self.isAuthenticated = tokens.refreshToken != nil
            }
        } catch {
            Logger.psn.error("Failed to load PSN credentials from keychain: \(error.localizedDescription)")
        }
    }
    
    private func saveAccount(_ account: PSNAccount) throws {
        let data = try JSONEncoder().encode(account)
        try KeychainManager.shared.save(key: keychainAccountKey, data: data)
    }
    
    private func saveTokens(_ tokens: PSNTokens) throws {
        let data = try JSONEncoder().encode(tokens)
        try KeychainManager.shared.save(key: keychainTokensKey, data: data)
    }
    
    private func exchangeCodeForTokens(_ code: String) async throws -> PSNTokens {
        var request = URLRequest(url: URL(string: tokenUrl)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyItems = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectUri,
            "client_id": clientId,
            "scope": scope
        ]
        
        request.httpBody = bodyItems.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            Logger.psn.error("Token exchange failed: \(errorBody)")
            throw NSError(domain: "PSNService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to exchange code for tokens"])
        }
        
        let responseJson = try JSONDecoder().decode(PSNTokenResponse.self, from: data)
        return PSNTokens(
            accessToken: responseJson.accessToken,
            refreshToken: responseJson.refreshToken,
            expiresIn: responseJson.expiresIn,
            expirationDate: Date().addingTimeInterval(TimeInterval(responseJson.expiresIn))
        )
    }
    
    private func refreshTokens() async throws {
        guard let refreshToken = tokens?.refreshToken else {
            throw NSError(domain: "PSNService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No refresh token available"])
        }
        
        var request = URLRequest(url: URL(string: tokenUrl)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyItems = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientId,
            "scope": scope
        ]
        
        request.httpBody = bodyItems.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "PSNService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to refresh tokens"])
        }
        
        let responseJson = try JSONDecoder().decode(PSNTokenResponse.self, from: data)
        let newTokens = PSNTokens(
            accessToken: responseJson.accessToken,
            refreshToken: responseJson.refreshToken ?? refreshToken,
            expiresIn: responseJson.expiresIn,
            expirationDate: Date().addingTimeInterval(TimeInterval(responseJson.expiresIn))
        )
        
        try saveTokens(newTokens)
        self.tokens = newTokens
    }
    
    private func fetchProfile(accessToken: String) async throws -> PSNProfileResponse {
        var request = URLRequest(url: URL(string: profileUrl)!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "PSNService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch profile"])
        }
        
        return try JSONDecoder().decode(PSNProfileResponse.self, from: data)
    }
}

// MARK: - Internal Helper Models

private struct PSNTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

private struct PSNProfileResponse: Codable {
    let onlineId: String
    let accountId: String
}
