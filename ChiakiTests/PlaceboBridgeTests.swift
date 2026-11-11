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
import Metal
import CoreVideo
@testable import Chiaki

@Suite("PlaceboContext C/Swift 桥接层验证")
struct PlaceboBridgeTests {

    private func requireBridgeAvailable() -> PlaceboContext? {
        PlaceboContext()
    }

    /**
     * @verifies AC-173
     * @testcase UT-061.1
     */
    @Test("PlaceboContext 可初始化且 isAvailable 不崩溃")
    func testContextInitAndAvailability() throws {
        guard let context = requireBridgeAvailable() else { return }
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
        guard let context = requireBridgeAvailable() else { return }
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
    @Test("级联初始化: createRenderer 隐式创建 log + gpu")
    func testCascadeInit() throws {
        guard let context = requireBridgeAvailable() else { return }
        _ = context.createRenderer()

        if context.isAvailable {
            // Log creation should always succeed when libplacebo is available
            #expect(context.logHandle != nil)
            // Metal GPU creation fails on pre-Apple7 GPUs (Intel Macs),
            // so only assert it's non-nil if the renderer was actually created.
            if context.rendererHandle != nil {
                #expect(context.gpuHandle != nil)
            }
        }
    }

    /**
     * @verifies AC-173
     * @testcase UT-061.4
     */
    @Test("deinit 后资源正确释放（无泄漏）")
    func testDeinitCleansUp() throws {
        var context: PlaceboContext? = requireBridgeAvailable()
        guard context != nil else { return }
        _ = context?.createRenderer()
        context = nil
        // If deinit double-frees, this test would crash.
        // Token handles use chiakiDestroyTokenHandle which nulls pointer safely.
    }

    /**
     * @verifies AC-188
     * @testcase UT-067.1
     */
    @Test("Apple7+ GPU 上 pl_metal_create 成功")
    func testMetalGPUCreatesOnApple7() throws {
        guard let context = requireBridgeAvailable(), context.isAvailable,
              let device = MTLCreateSystemDefaultDevice(), device.supportsFamily(.apple7) else { return }
        #expect(context.createGPU() != nil)
    }

    /**
     * @verifies AC-177, AC-188
     * @testcase UT-067.2
     */
    /// Expected values are the BT.709 limited-range matrix applied by hand:
    /// R = Y + 1.5748 Cr, G = Y - 0.1873 Cb - 0.4681 Cr, B = Y + 1.8556 Cb,
    /// with Y = (Y' - 16) / 219 and Cb/Cr = (C - 128) / 224, scaled to 0...255.
    @Test("Metal 后端 NV12 BT.709 → RGB 像素值正确", arguments: [
        (y: UInt8(16), cb: UInt8(128), cr: UInt8(128), rgb: (0, 0, 0)),         // black
        (y: 235, cb: 128, cr: 128, rgb: (255, 255, 255)),                         // white
        (y: 126, cb: 128, cr: 128, rgb: (128, 128, 128)),                         // 50% gray
        (y: 63, cb: 102, cr: 240, rgb: (255, 1, 0)),                              // BT.709 red
        (y: 145, cb: 54, cr: 34, rgb: (0, 216, 0)),                               // green, R/B clip
    ])
    func testNV12ToRGBPixelValues(_ sample: (y: UInt8, cb: UInt8, cr: UInt8, rgb: (Int, Int, Int))) throws {
        guard let context = requireBridgeAvailable(), context.isAvailable,
              let device = MTLCreateSystemDefaultDevice(), device.supportsFamily(.apple7) else { return }

        let width = 64, height = 64
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &pixelBuffer)
        let buffer = try #require(pixelBuffer)

        CVPixelBufferLockBaseAddress(buffer, [])
        let yBase = CVPixelBufferGetBaseAddressOfPlane(buffer, 0)!
        memset(yBase, Int32(sample.y), CVPixelBufferGetBytesPerRowOfPlane(buffer, 0) * height)
        let uvBase = CVPixelBufferGetBaseAddressOfPlane(buffer, 1)!.assumingMemoryBound(to: UInt8.self)
        let uvCount = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1) * (height / 2)
        for i in stride(from: 0, to: uvCount, by: 2) {
            uvBase[i] = sample.cb
            uvBase[i + 1] = sample.cr
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])

        let surface = try #require(CVPixelBufferGetIOSurface(buffer)?.takeUnretainedValue())
        let pixels = try #require(context.renderIOSurfaceToRGBA(
            ioSurface: Unmanaged.passUnretained(surface).toOpaque(), planeCount: 2, width: width, height: height
        ))

        let center = ((height / 2) * width + width / 2) * 4
        let actual = (Int(pixels[center]), Int(pixels[center + 1]), Int(pixels[center + 2]))
        #expect(abs(actual.0 - sample.rgb.0) <= 2, "R \(actual) vs \(sample.rgb)")
        #expect(abs(actual.1 - sample.rgb.1) <= 2, "G \(actual) vs \(sample.rgb)")
        #expect(abs(actual.2 - sample.rgb.2) <= 2, "B \(actual) vs \(sample.rgb)")
    }

    /**
     * @verifies AC-173
     * @testcase UT-061.6
     */
    @Test("PlaceboRenderParams 预设值正确")
    func testRenderParamsPresets() {
        #expect(PlaceboRenderParams.performance.enableDeband == false)
        #expect(PlaceboRenderParams.performance.upscaler == .bilinear)
        #expect(PlaceboRenderParams.default.enableDeband == true)
        #expect(PlaceboRenderParams.default.upscaler == .lanczos)
        #expect(PlaceboRenderParams.highQuality.enableSigmoidUpScaling == true)
        #expect(PlaceboRenderParams.highQuality.upscaler == .ewaLanczosSharp)
    }
}
