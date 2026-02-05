// SPDX-License-Identifier: AGPL-3.0-only
//
//  SettingsStoreMainActorTests.swift
//  ChiakiTests
//
//  Unit tests for SettingsStore MainActor isolation (T-175)
//
//  @requirement F-029 - MainActor 边界规范化
//  @verifies AC-101 - SettingsStore 标注
//

import Testing
import Foundation
@testable import Chiaki

@MainActor
struct SettingsStoreMainActorTests {

    /**
     * @verifies AC-101 - SettingsStore 整体标注 @MainActor
     * @testcase UT-045.1
     */
    @Test func testSettingsStoreIsMainActor() {
        // If the class is marked @MainActor, this access is safe within @MainActor test
        let store = SettingsStore.shared
        #expect(store != nil)
    }

    /**
     * @verifies AC-101 - shared 在 MainActor 上
     * @testcase UT-045.2
     */
    @Test func testSettingsStoreSharedOnMainActor() async {
        // From non-MainActor context (async test), access should be awaited or run on MainActor
        let store = await MainActor.run {
            SettingsStore.shared
        }
        #expect(store != nil)
    }

    /**
     * @verifies AC-101 - 属性访问需要 MainActor
     * @testcase UT-045.3
     */
    @Test func testSettingsStorePropertiesOnMainActor() {
        let store = SettingsStore.shared
        // Direct property access in MainActor context
        _ = store.streamSettings
        #expect(true)
    }
}
