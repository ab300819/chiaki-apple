// SPDX-License-Identifier: AGPL-3.0-only
//
// PinManaging.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// PIN management abstraction

import Foundation

/// PIN 管理协议
/// @requirement F-027 - UI 层 MVVM 合规重构
/// @satisfies AC-095 - 协议抽象: PinManaging
protocol PinManaging: AnyObject, Sendable {
    /// 设置 PIN
    func setPin(_ pin: String, for host: ConsoleHost)

    /// 清除 PIN
    func clearPin(for host: ConsoleHost)

    /// 检查是否有 PIN
    func hasPin(for host: ConsoleHost) -> Bool

    /// 检查是否需要 PIN 输入
    func requiresPinEntry(for host: ConsoleHost) -> Bool

    /// 获取 PIN (如果存在)
    func getPin(for host: ConsoleHost) -> String?
}
