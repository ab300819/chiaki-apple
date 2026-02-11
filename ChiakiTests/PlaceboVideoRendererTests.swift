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
}
