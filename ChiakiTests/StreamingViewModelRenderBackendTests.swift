// SPDX-License-Identifier: AGPL-3.0-only
//
// StreamingViewModelRenderBackendTests.swift
// ChiakiTests
//
// @requirement F-042 - libplacebo 渲染后端集成
// @verifies AC-180, AC-184, AC-185

import Foundation
import MetalKit
import CoreVideo
import Testing
@testable import Chiaki

@MainActor
@Suite("UT-064 StreamingViewModel 后端工厂")
struct StreamingViewModelRenderBackendTests {

    private final class DummyRenderer: VideoRenderer, @unchecked Sendable {
        weak var mtkView: MTKView?
        var displayMode: VideoDisplayMode = .normal
        var zoomFactor: Float = 1.0
        var vrrEnabled: Bool = false
        var hdrConfiguration: HDRConfiguration = .sdr
        var edrHeadroom: Float = 1.0
        var filterConfig: VideoFilterConfig = .default
        var frameSize: CGSize = .zero
        var hasFrame: Bool = false
        var frameCount: UInt64 = 0
        var droppedFrameCount: UInt64 = 0
        var onFrameSubmitted: ((CVPixelBuffer) -> Void)?
        var onRenderTimeRecorded: ((Double) -> Void)?

        func submitFrame(_ pixelBuffer: CVPixelBuffer) {}
        func setFilterConfig(_ config: VideoFilterConfig) {}
        func setBrightness(_ value: Float) {}
        func setContrast(_ value: Float) {}
        func setSaturation(_ value: Float) {}
        func setColorSpace(_ value: UInt32) {}
        func updateRenderingPolicy(fps: Int?) {}
        func updateViewSize(_ size: CGSize) {}
        func flushTextureCache() {}
        func render(to view: MTKView, descriptor: MTLRenderPassDescriptor?) {}
        func resetStatistics() {}
    }

    private func makeViewModel() -> StreamingViewModel {
        StreamingViewModel(host: ConsoleHost(nickname: "test", address: "127.0.0.1"))
    }

    /**
     * @verifies AC-180
     * @testcase UT-064.4
     */
    @Test("libplacebo 后端选择时返回 Placebo 渲染器")
    func testCreateRendererLibplacebo() {
        let viewModel = makeViewModel()
        let placebo = DummyRenderer()
        let metal = DummyRenderer()

        let renderer = viewModel.createRenderer(
            renderBackend: .libplacebo,
            placeboFactory: { placebo },
            metalFactory: { metal }
        )

        #expect(renderer as AnyObject === placebo)
    }

    /**
     * @verifies AC-180
     * @testcase UT-064.5
     */
    @Test("Metal Native 后端选择时返回 Metal 渲染器")
    func testCreateRendererMetalNative() {
        let viewModel = makeViewModel()
        let metal = DummyRenderer()

        let renderer = viewModel.createRenderer(
            renderBackend: .metalNative,
            placeboFactory: { DummyRenderer() },
            metalFactory: { metal }
        )

        #expect(renderer as AnyObject === metal)
    }

    /**
     * @verifies AC-184, AC-185
     * @testcase UT-064.6
     */
    @Test("libplacebo 初始化失败时自动回退 Metal")
    func testGracefulFallback() {
        let viewModel = makeViewModel()
        let metal = DummyRenderer()

        let renderer = viewModel.createRenderer(
            renderBackend: .libplacebo,
            placeboFactory: { nil },
            metalFactory: { metal }
        )

        #expect(renderer as AnyObject === metal)
    }
}
