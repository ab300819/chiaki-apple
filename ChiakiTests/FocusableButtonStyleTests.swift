// SPDX-License-Identifier: AGPL-3.0-only
//
// FocusableButtonStyleTests.swift
// ChiakiTests
//
// Tests for tvOS button focus visual feedback

import Testing
import SwiftUI
@testable import Chiaki

/**
 * @requirement F-020 - 手柄操作友好化
 * @satisfies AC-056 - tvOS 焦点视觉反馈
 */
@MainActor
struct FocusableButtonStyleTests {

    /**
     * @verifies AC-056 - tvOS 焦点视觉反馈
     * @testcase UT-011.1
     */
    @Test func testFocusedScaleEffectValue() {
        #expect(FocusableButtonStyle.focusedScale == 1.05)
    }

    /**
     * @verifies AC-056 - tvOS 焦点视觉反馈
     * @testcase UT-011.2
     */
    @Test func testUnfocusedScaleEffectValue() {
        #expect(FocusableButtonStyle.unfocusedScale == 1.0)
    }

    /**
     * @verifies AC-056 - tvOS 焦点视觉反馈
     * @testcase UT-011.4
     */
    @Test func testAnimationDurationValue() {
        #expect(FocusableButtonStyle.animationDuration == 0.15)
    }
}
