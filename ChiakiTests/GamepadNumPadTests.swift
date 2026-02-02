// SPDX-License-Identifier: AGPL-3.0-only
//
// GamepadNumPadTests.swift
// ChiakiTests
//
// Tests for GamepadNumPad component (TDD - Test First)

import Testing
import Foundation
@testable import Chiaki

/**
 * GamepadNumPad Tests
 * @requirement F-022 - 手柄操控 UI/UX 优化
 * @verifies AC-067 - PIN 输入数字键盘优化
 */
@Suite("GamepadNumPad Tests", .serialized)
struct GamepadNumPadTests {

    // MARK: - UT-019.1: NumPadKey Enum Cases

    /**
     * @verifies AC-067 - 键位枚举完整性
     * @testcase UT-019.1
     */
    @Test("NumPadKey enum contains all required keys")
    func testNumPadKeyEnumCases() {
        // Verify digit keys exist
        let digitKeys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
        for digit in digitKeys {
            let key = NumPadKey(rawValue: digit)
            #expect(key != nil, "Digit key '\(digit)' should exist")
        }

        // Verify special keys
        #expect(NumPadKey.backspace != nil)
        #expect(NumPadKey.empty != nil)

        // Verify all 12 cases exist (10 digits + backspace + empty)
        let allCases = NumPadKey.allCases
        #expect(allCases.count == 12)
    }

    // MARK: - UT-019.2: Layout Structure

    /**
     * @verifies AC-067 - 3×4 布局结构
     * @testcase UT-019.2
     */
    @Test("NumPad has 3x4 layout (4 rows × 3 columns)")
    func testNumPadLayoutStructure() {
        let layout = NumPadLayout.standard

        #expect(layout.rows.count == 4, "Should have 4 rows")

        for (index, row) in layout.rows.enumerated() {
            #expect(row.count == 3, "Row \(index) should have 3 columns")
        }

        // Verify standard layout order: 1-2-3, 4-5-6, 7-8-9, empty-0-backspace
        #expect(layout.rows[0] == [.digit1, .digit2, .digit3])
        #expect(layout.rows[1] == [.digit4, .digit5, .digit6])
        #expect(layout.rows[2] == [.digit7, .digit8, .digit9])
        #expect(layout.rows[3] == [.empty, .digit0, .backspace])
    }

    // MARK: - UT-019.3: Digit Input

    /**
     * @verifies AC-067 - 数字输入追加
     * @testcase UT-019.3
     */
    @Test("Digit input appends to value")
    func testDigitInput() {
        var value = ""

        // Input first digit
        NumPadInputHandler.handleKeyPress(.digit1, value: &value, maxLength: 4)
        #expect(value == "1")

        // Input second digit
        NumPadInputHandler.handleKeyPress(.digit2, value: &value, maxLength: 4)
        #expect(value == "12")

        // Input third digit
        NumPadInputHandler.handleKeyPress(.digit3, value: &value, maxLength: 4)
        #expect(value == "123")

        // Input fourth digit
        NumPadInputHandler.handleKeyPress(.digit4, value: &value, maxLength: 4)
        #expect(value == "1234")
    }

    // MARK: - UT-019.4: Backspace Delete

    /**
     * @verifies AC-067 - 退格删除最后一位
     * @testcase UT-019.4
     */
    @Test("Backspace deletes last character")
    func testBackspaceDelete() {
        var value = "123"

        // Delete last character
        NumPadInputHandler.handleKeyPress(.backspace, value: &value, maxLength: 4)
        #expect(value == "12")

        // Delete again
        NumPadInputHandler.handleKeyPress(.backspace, value: &value, maxLength: 4)
        #expect(value == "1")

        // Delete last
        NumPadInputHandler.handleKeyPress(.backspace, value: &value, maxLength: 4)
        #expect(value == "")

        // Backspace on empty string should not crash
        NumPadInputHandler.handleKeyPress(.backspace, value: &value, maxLength: 4)
        #expect(value == "")
    }

    // MARK: - UT-019.5: Max Length Limit

    /**
     * @verifies AC-067 - 超过 maxLength 不追加
     * @testcase UT-019.5
     */
    @Test("Input is limited to maxLength")
    func testMaxLengthLimit() {
        var value = "1234"

        // Try to add 5th digit (should be ignored)
        NumPadInputHandler.handleKeyPress(.digit5, value: &value, maxLength: 4)
        #expect(value == "1234", "Should not exceed maxLength")

        // Try another digit
        NumPadInputHandler.handleKeyPress(.digit6, value: &value, maxLength: 4)
        #expect(value == "1234", "Should still not exceed maxLength")
    }

    // MARK: - UT-019.6: Auto Complete on Max Length

    /**
     * @verifies AC-067 - 达到 maxLength 时触发 onComplete
     * @testcase UT-019.6
     */
    @Test("Auto complete triggers when maxLength is reached")
    func testAutoCompleteOnMaxLength() {
        var value = "123"
        var completedValue: String?

        // Input 4th digit - should trigger completion
        NumPadInputHandler.handleKeyPress(.digit4, value: &value, maxLength: 4) { finalValue in
            completedValue = finalValue
        }

        #expect(value == "1234")
        #expect(completedValue == "1234", "onComplete should be called with final value")
    }

    // MARK: - UT-019.7: Empty Key Disabled

    /**
     * @verifies AC-067 - empty 键不响应操作
     * @testcase UT-019.7
     */
    @Test("Empty key does not modify value")
    func testEmptyKeyDisabled() {
        var value = "12"

        // Press empty key
        NumPadInputHandler.handleKeyPress(.empty, value: &value, maxLength: 4)

        #expect(value == "12", "Empty key should not change value")
    }

    // MARK: - UT-019.8: Default Focus Position

    /**
     * @verifies AC-067 - 默认聚焦到"5"键（中间位置）
     * @testcase UT-019.8
     */
    @Test("Default focus is on digit 5 (center)")
    func testDefaultFocusPosition() {
        let defaultFocus = NumPadLayout.defaultFocusKey

        #expect(defaultFocus == .digit5, "Default focus should be digit 5 (center)")
    }

    // MARK: - Additional: Key Display Values

    /**
     * @verifies AC-067 - 键位显示文本
     */
    @Test("Keys have correct display values")
    func testKeyDisplayValues() {
        #expect(NumPadKey.digit0.displayValue == "0")
        #expect(NumPadKey.digit1.displayValue == "1")
        #expect(NumPadKey.digit5.displayValue == "5")
        #expect(NumPadKey.digit9.displayValue == "9")
        #expect(NumPadKey.backspace.displayValue == "⌫")
        #expect(NumPadKey.empty.displayValue == "")
    }

    // MARK: - Additional: Completion Not Called Before MaxLength

    /**
     * @verifies AC-067 - maxLength 前不触发 onComplete
     */
    @Test("Completion not called before maxLength")
    func testCompletionNotCalledBeforeMaxLength() {
        var value = ""
        var completionCalled = false

        // Input digits but not reaching maxLength
        NumPadInputHandler.handleKeyPress(.digit1, value: &value, maxLength: 4) { _ in
            completionCalled = true
        }
        #expect(completionCalled == false)

        NumPadInputHandler.handleKeyPress(.digit2, value: &value, maxLength: 4) { _ in
            completionCalled = true
        }
        #expect(completionCalled == false)

        NumPadInputHandler.handleKeyPress(.digit3, value: &value, maxLength: 4) { _ in
            completionCalled = true
        }
        #expect(completionCalled == false)

        #expect(value == "123")
    }
}
