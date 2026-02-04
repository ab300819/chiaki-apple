// SPDX-License-Identifier: AGPL-3.0-only
//
// PSNServicing.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// PSN service abstraction

import Foundation

/// PSN 登录状态
enum PSNAuthState: String {
    case signedOut
    case signingIn
    case signedIn
}

/// PSN 服务协议
/// @requirement F-027 - UI 层 MVVM 合规重构
/// @satisfies AC-095 - 协议抽象: PSNServicing
protocol PSNServicing: AnyObject {
    /// 当前账户
    var account: PSNAccount? { get }

    /// 是否已登录
    var isSignedIn: Bool { get }

    /// 登录状态
    var authState: PSNAuthState { get }

    /// 登出
    func signOut()

    /// 手动刷新 Token
    func manualRefresh() async throws

    /// 开始 OAuth 登录
    func startOAuthLogin() -> URL
}

/// @requirement F-027 - UI 层 MVVM 合规重构
/// @satisfies AC-095 - 协议抽象: PSNServicing
extension PSNService: PSNServicing {
    var isSignedIn: Bool {
        isAuthenticated
    }

    var authState: PSNAuthState {
        if isAuthenticating {
            return .signingIn
        }
        return isAuthenticated ? .signedIn : .signedOut
    }

    func startOAuthLogin() -> URL {
        getLoginUrl()
    }
}
