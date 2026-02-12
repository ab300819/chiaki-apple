// SPDX-License-Identifier: AGPL-3.0-only
//
// StreamSettingsRenderBackendTests.swift
// ChiakiTests
//
// @requirement F-042 - libplacebo 渲染后端集成
// @verifies AC-178 - renderBackend 设置属性

import Foundation
import Testing
@testable import Chiaki

@Suite("UT-064 RenderBackend 设置与持久化")
struct StreamSettingsRenderBackendTests {

    /**
     * @verifies AC-178
     * @testcase UT-064.1
     */
    @Test("RenderBackend 枚举包含 metalNative 与 libplacebo")
    func testRenderBackendEnumCases() {
        let allCases = Set(StreamSettings.RenderBackend.allCases)
        #expect(allCases == Set([.metalNative, .libplacebo]))
    }

    /**
     * @verifies AC-178
     * @testcase UT-064.2
     */
    @Test("默认 renderBackend 为 libplacebo")
    func testDefaultBackendIsLibplacebo() {
        let settings = StreamSettings()
        #expect(settings.renderBackend == .libplacebo)
    }

    /**
     * @verifies AC-178
     * @testcase UT-064.3
     */
    @Test("RenderBackend Codable 与旧数据兼容")
    func testRenderBackendCodable() throws {
        var settings = StreamSettings()
        settings.renderBackend = .metalNative

        let encoded = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(StreamSettings.self, from: encoded)
        #expect(decoded.renderBackend == .metalNative)

        let legacyData = Data("{}".utf8)
        let legacyDecoded = try JSONDecoder().decode(StreamSettings.self, from: legacyData)
        #expect(legacyDecoded.renderBackend == .libplacebo)
    }
}
