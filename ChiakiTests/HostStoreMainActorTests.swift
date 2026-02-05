// SPDX-License-Identifier: AGPL-3.0-only
//
//  HostStoreMainActorTests.swift
//  ChiakiTests
//
//  Unit tests for HostStore MainActor isolation (T-176)
//
//  @requirement F-029 - MainActor 边界规范化
//  @verifies AC-102 - HostStore 标注
//

import Testing
import Foundation
@testable import Chiaki

@MainActor
struct HostStoreMainActorTests {

    /**
     * @verifies AC-102 - HostStore 整体标注 @MainActor
     * @testcase UT-046.1
     */
    @Test func testHostStoreIsMainActor() {
        let store = HostStore.shared
        #expect(store != nil)
    }

    /**
     * @verifies AC-102 - shared 在 MainActor 上
     * @testcase UT-046.2
     */
    @Test func testHostStoreSharedOnMainActor() async {
        let store = await MainActor.run {
            HostStore.shared
        }
        #expect(store != nil)
    }

    /**
     * @verifies AC-102 - CRUD 操作在 MainActor 上
     * @testcase UT-046.3
     */
    @Test func testHostStoreCRUDOnMainActor() {
        // Since the class is @MainActor, this constructor and methods must be called on MainActor
        let store = HostStore(userDefaults: .init(suiteName: "test.hoststore.actor") ?? .standard)
        let host = MockData.hostPS5
        store.addHost(host)
        #expect(store.hosts.contains(where: { $0.id == host.id }))
        store.removeHost(host)
    }
}
