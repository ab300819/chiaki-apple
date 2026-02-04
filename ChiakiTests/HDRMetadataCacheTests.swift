// SPDX-License-Identifier: AGPL-3.0-only
//
// HDRMetadataCacheTests.swift
// ChiakiTests
//
// Unit tests for HDRMetadataCache jitter suppression
// @requirement F-025 - HDR 渲染管线优化
//

import XCTest
@testable import Chiaki

/// @verifies AC-083 - 元数据抖动抑制
final class HDRMetadataCacheTests: XCTestCase {

    var cache: HDRMetadataCache!

    override func setUp() {
        super.setUp()
        cache = HDRMetadataCache()
    }

    override func tearDown() {
        cache = nil
        super.tearDown()
    }

    // MARK: - UT-029.1: Initial State

    /// @verifies AC-083
    /// @testcase UT-029.1
    func testInitialState() {
        XCTAssertFalse(cache.confirmedHDR, "初始状态应为 SDR (false)")
    }

    // MARK: - UT-029.2: Confirm HDR Transition

    /// @verifies AC-083
    /// @testcase UT-029.2
    func testConfirmHDRTransition() {
        // 连续提交 4 帧 HDR，不应改变状态
        for i in 1...4 {
            cache.update(isHDRFrame: true)
            XCTAssertFalse(cache.confirmedHDR, "提交 \(i) 帧 HDR 后，状态仍应为 SDR")
        }

        // 提交第 5 帧 HDR，应该切换到 HDR 模式
        cache.update(isHDRFrame: true)
        XCTAssertTrue(cache.confirmedHDR, "连续提交 5 帧 HDR 后，状态应切换为 HDR")
    }

    // MARK: - UT-029.3: Jitter Suppression (HDR -> SDR)

    /// @verifies AC-083
    /// @testcase UT-029.3
    func testJitterSuppressionHDRToSDR() {
        // 先进入 HDR 模式
        for _ in 1...5 {
            cache.update(isHDRFrame: true)
        }
        XCTAssertTrue(cache.confirmedHDR)

        // 提交 1 帧 SDR (抖动)，不应改变状态
        cache.update(isHDRFrame: false)
        XCTAssertTrue(cache.confirmedHDR, "单帧 SDR 抖动不应改变 HDR 状态")

        // 提交更多 SDR 帧但未达到阈值
        for i in 2...4 {
            cache.update(isHDRFrame: false)
            XCTAssertTrue(cache.confirmedHDR, "提交 \(i) 帧 SDR 后，状态仍应为 HDR")
        }

        // 如果中间出现一帧 HDR，计数器应该重置（假设实现逻辑是连续确认）
        // 这里的需求是“连续 5 帧”，所以如果中间断了，应该重新开始计数
        cache.update(isHDRFrame: true)
        
        // 再次提交 4 帧 SDR
        for _ in 1...4 {
            cache.update(isHDRFrame: false)
        }
        XCTAssertTrue(cache.confirmedHDR, "由于中间插入了 HDR 帧，4 帧 SDR 后状态仍应为 HDR")
    }

    // MARK: - UT-029.4: Confirm SDR Transition

    /// @verifies AC-083
    /// @testcase UT-029.4
    func testConfirmSDRTransition() {
        // 先进入 HDR 模式
        for _ in 1...5 {
            cache.update(isHDRFrame: true)
        }
        XCTAssertTrue(cache.confirmedHDR)

        // 连续提交 5 帧 SDR
        for _ in 1...5 {
            cache.update(isHDRFrame: false)
        }
        XCTAssertFalse(cache.confirmedHDR, "连续提交 5 帧 SDR 后，状态应切换回 SDR")
    }

    // MARK: - UT-029.5: Reset

    /// @verifies AC-083
    /// @testcase UT-029.5
    func testReset() {
        // 先进入 HDR 模式
        for _ in 1...5 {
            cache.update(isHDRFrame: true)
        }
        XCTAssertTrue(cache.confirmedHDR)

        // 重置
        cache.reset()
        XCTAssertFalse(cache.confirmedHDR, "reset() 后状态应恢复为 SDR")
        
        // 验证计数器也已重置
        cache.update(isHDRFrame: true)
        XCTAssertFalse(cache.confirmedHDR)
    }
}
