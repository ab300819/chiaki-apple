// SPDX-License-Identifier: AGPL-3.0-only
//
//  PlaceboVideoRendererTests.swift
//  ChiakiTests
//
//  @requirement F-042 - libplacebo 渲染后端集成
//  @verifies AC-173 - PlaceboVideoRenderer 协议实现
//

import Testing
import Foundation
import MetalKit
import CoreVideo
@testable import Chiaki

@Suite("UT-061 PlaceboVideoRenderer 协议与初始化")
struct PlaceboVideoRendererTests {

    private func createTestView() -> MTKView {
        let device = MTLCreateSystemDefaultDevice()
        return MTKView(frame: CGRect(x: 0, y: 0, width: 100, height: 100), device: device)
    }

    private func requireRenderer() throws -> PlaceboVideoRenderer {
        guard let renderer = PlaceboVideoRenderer() else {
            throw Skip("PlaceboVideoRenderer not available (missing libplacebo/MoltenVK frameworks)")
        }
        return renderer
    }

    /**
     * @verifies AC-173
     * @testcase UT-061.1
     */
    @Test("PlaceboVideoRenderer 符合 VideoRenderer 协议")
    func testConformsToVideoRenderer() throws {
        let renderer = try requireRenderer()
        let protocolRenderer: any VideoRenderer = renderer as any VideoRenderer
        #expect(protocolRenderer != nil)
    }

    /**
     * @verifies AC-173
     * @testcase UT-061.2
     */
    @Test("正常初始化：返回非 nil")
    func testInitReturnsNonNil() throws {
        let renderer = PlaceboVideoRenderer()
        #expect(renderer != nil)
    }

    /**
     * @verifies AC-173
     * @testcase UT-061.3
     */
    @Test("默认属性值正确")
    func testInitialPropertyDefaults() throws {
        let renderer = try requireRenderer()
        #expect(renderer.displayMode == .normal)
        #expect(renderer.zoomFactor == 1.0)
        #expect(renderer.vrrEnabled == false)
        #expect(renderer.hasFrame == false)
        #expect(renderer.frameSize == .zero)
        #expect(renderer.frameCount == 0)
        #expect(renderer.droppedFrameCount == 0)
        #expect(renderer.edrHeadroom == 1.0)
    }

    /**
     * @verifies AC-173
     * @testcase UT-061.4
     */
    @Test("显示模式设置与读取")
    func testDisplayModeSetGet() throws {
        let renderer = try requireRenderer()
        
        renderer.displayMode = .stretch
        #expect(renderer.displayMode == .stretch)
        
        renderer.displayMode = .zoom
        #expect(renderer.displayMode == .zoom)
        
        renderer.displayMode = .normal
        #expect(renderer.displayMode == .normal)
    }

    /**
     * @verifies AC-173
     */
    @Test("MTKView 关联测试")
    func testMTKViewAssociation() throws {
        let renderer = try requireRenderer()
        let view = createTestView()
        
        renderer.mtkView = view
        #expect(renderer.mtkView === view)
    }

    /**
     * @verifies AC-173
     */
    @Test("缩放因子设置范围")
    func testZoomFactorSetGet() throws {
        let renderer = try requireRenderer()
        
        renderer.zoomFactor = 1.5
        #expect(renderer.zoomFactor == 1.5)
        
        renderer.zoomFactor = 2.0
        #expect(renderer.zoomFactor == 2.0)
    }

    /**
     * @verifies AC-181
     * @testcase UT-063.1
     */
    @Test("Performance 预设映射为 fast + bilinear")
    func testPerformancePresetMapping() {
        let params = PlaceboFrameParams.map(
            filterConfig: .performance,
            hdrConfiguration: .sdr,
            edrHeadroom: 1.0,
            adjustment: PlaceboColorAdjustment(),
            colorSpace: 0
        )

        #expect(params.render.preset == .performance)
        #expect(params.render.upscaler == .bilinear)
        #expect(params.deband.iterations == 0)
    }

    /**
     * @verifies AC-181, AC-182
     * @testcase UT-063.2
     */
    @Test("Default 预设映射为 default + deband")
    func testDefaultPresetMapping() {
        let params = PlaceboFrameParams.map(
            filterConfig: .default,
            hdrConfiguration: .sdr,
            edrHeadroom: 1.0,
            adjustment: PlaceboColorAdjustment(),
            colorSpace: 0
        )

        #expect(params.render.preset == .default)
        #expect(params.render.upscaler == .lanczos)
        #expect(params.deband.iterations > 0)
        #expect(params.deband.iterations == PlaceboDebandParams.default.iterations)
    }

    /**
     * @verifies AC-181, AC-182, AC-183
     * @testcase UT-063.3
     */
    @Test("High Quality 预设映射为 high_quality + ewa_lanczossharp")
    func testHighQualityPresetMapping() {
        let params = PlaceboFrameParams.map(
            filterConfig: .highQuality,
            hdrConfiguration: .sdr,
            edrHeadroom: 1.0,
            adjustment: PlaceboColorAdjustment(),
            colorSpace: 0
        )

        #expect(params.render.preset == .highQuality)
        #expect(params.render.upscaler == .ewaLanczosSharp)
        #expect(params.deband.iterations > 0)
    }

    /**
     * @verifies AC-177
     * @testcase IT-022.2
     */
    @Test("HDR 映射注入 targetMaxLuma")
    func testHDRHeadroomMapping() {
        let params = PlaceboFrameParams.map(
            filterConfig: .default,
            hdrConfiguration: .hdr,
            edrHeadroom: 3.0,
            adjustment: PlaceboColorAdjustment(),
            colorSpace: 2
        )

        #expect(params.render.tonemapEnabled == true)
        #expect(params.render.targetMaxLuma == 609.0)
        #expect(params.render.colorSpace == 2)
    }

    /**
     * @verifies AC-187
     * @testcase UT-065.3
     */
    @Test("诊断标识返回 libplacebo")
    func testFilterNameReturnsLibplacebo() throws {
        let renderer = try requireRenderer()
        #expect(renderer.filterName == "libplacebo")
    }

    /**
     * @verifies AC-186
     * @testcase UT-065.4
     */
    @Test("重置统计会清零扩展诊断字段")
    func testResetStatisticsResetsDiagnostics() throws {
        let renderer = try requireRenderer()
        renderer.resetStatistics()
        #expect(renderer.frameCount == 0)
        #expect(renderer.droppedFrameCount == 0)
        #expect(renderer.frameRepeatCount == 0)
        #expect(renderer.presentInterval == 0)
    }

    /**
     * @verifies AC-190
     * @testcase UT-066.2
     */
    @Test("Shader 缓存可持久化写入文件")
    func testShaderCachePersistence() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cacheURL = tempDir.appendingPathComponent("placebo_cache.bin", isDirectory: false)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        guard let renderer = PlaceboVideoRenderer(shaderCacheFileURL: cacheURL) else {
            throw Skip("PlaceboVideoRenderer not available (missing libplacebo/MoltenVK frameworks)")
        }

        #expect(renderer.saveShaderCacheForTesting())
        #expect(FileManager.default.fileExists(atPath: cacheURL.path))
    }
}
