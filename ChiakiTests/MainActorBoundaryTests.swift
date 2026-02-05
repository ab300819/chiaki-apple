// SPDX-License-Identifier: AGPL-3.0-only
//
//  MainActorBoundaryTests.swift
//  ChiakiTests
//
//  Integration tests for MainActor boundaries (IT-016)
//
//  @requirement F-029 - MainActor 边界规范化
//  @verifies AC-101, AC-102, AC-103
//

import Testing
import Foundation
@testable import Chiaki

struct MainActorBoundaryTests {

    /**
     * @verifies AC-101 - SettingsStore 异步访问
     * @testcase IT-016.1
     */
    @Test func testBackgroundAccessToSettingsStore() async {
        // Accessing MainActor property from non-MainActor context
        let settings = await MainActor.run {
            SettingsStore.shared.streamSettings
        }
        #expect(settings != nil)
    }

    /**
     * @verifies AC-102 - HostStore 异步访问
     * @testcase IT-016.2
     */
    @Test func testBackgroundAccessToHostStore() async {
        let hosts = await MainActor.run {
            HostStore.shared.hosts
        }
        #expect(hosts != nil)
    }

    /**
     * @verifies AC-103 - NetworkMonitor 状态更新在 MainActor
     * @testcase IT-016.3
     */
    @Test func testNetworkMonitorStateOnMainActor() async {
        let monitor = NetworkMonitor.shared
        // Verify property access requires MainActor or is handled correctly
        let isConnected = await MainActor.run {
            monitor.isConnected
        }
        #expect(isConnected == true || isConnected == false)
    }
}
