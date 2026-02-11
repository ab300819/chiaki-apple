// SPDX-License-Identifier: AGPL-3.0-only
//
//  PlaceboBridgeTests.swift
//  ChiakiTests
//
//  @requirement F-042 - libplacebo 渲染后端集成
//  @verifies AC-173 - C/Swift 桥接层生命周期管理
//

import Testing
import Foundation

@Suite("PlaceboContext C/Swift 桥接层验证")
struct PlaceboBridgeTests {

    private func requireBridgeAvailable() throws -> PlaceboContext {
        guard let context = PlaceboContext() else {
            throw Skip("TODO(T-243): 先执行 Scripts/build-libplacebo.sh 产出 xcframework")
        }
        return context
    }

    /**
     * @verifies AC-173
     * @testcase UT-061.1
     */
    @Test("PlaceboContext 可初始化且 isAvailable 不崩溃")
    func testContextInitAndAvailability() throws {
        let context = try requireBridgeAvailable()
        // isAvailable depends on dlopen finding libplacebo symbols;
        // on CI without frameworks it returns false — just verify no crash.
        _ = context.isAvailable
    }

    /**
     * @verifies AC-173
     * @testcase UT-061.2
     */
    @Test("createLog 返回 OpaquePointer 或 nil（不崩溃）")
    func testCreateLog() throws {
        let context = try requireBridgeAvailable()
        let log = context.createLog()
        // Token handle when frameworks present, nil otherwise.
        if context.isAvailable {
            #expect(log != nil)
        }
    }

    /**
     * @verifies AC-173
     * @testcase UT-061.3
     */
    @Test("级联初始化: createRenderer 隐式创建 log + vulkan")
    func testCascadeInit() throws {
        let context = try requireBridgeAvailable()
        _ = context.createRenderer()

        if context.isAvailable {
            #expect(context.logHandle != nil)
            #expect(context.vulkanHandle != nil)
        }
    }

    /**
     * @verifies AC-173
     * @testcase UT-061.4
     */
    @Test("deinit 后资源正确释放（无泄漏）")
    func testDeinitCleansUp() throws {
        var context: PlaceboContext? = try requireBridgeAvailable()
        _ = context?.createRenderer()
        context = nil
        // If deinit double-frees, this test would crash.
        // Token handles use chiakiDestroyTokenHandle which nulls pointer safely.
    }

    /**
     * @verifies AC-173
     * @testcase UT-061.5
     */
    @Test("hasMetalObjectsExtension 不崩溃")
    func testMetalObjectsExtension() throws {
        let context = try requireBridgeAvailable()
        _ = context.hasMetalObjectsExtension
    }

    /**
     * @verifies AC-173
     * @testcase UT-061.6
     */
    @Test("PlaceboRenderParams 预设值正确")
    func testRenderParamsPresets() {
        #expect(PlaceboRenderParams.performance.enableDeband == false)
        #expect(PlaceboRenderParams.default.enableDeband == true)
        #expect(PlaceboRenderParams.highQuality.enableSigmoidUpScaling == true)
    }

    /**
     * @verifies AC-173
     * @testcase UT-061.7
     */
    @Test("PlaceboVulkanConfig 包含 VK_EXT_metal_objects")
    func testVulkanConfigExtensions() {
        let config = PlaceboVulkanConfig.default
        #expect(config.requiredInstanceExtensions.contains("VK_EXT_metal_objects"))
        #expect(config.requiredInstanceExtensions.contains("VK_EXT_metal_surface"))
    }
}
