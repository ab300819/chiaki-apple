// SPDX-License-Identifier: AGPL-3.0-only
//
// GamepadNumPad.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Gamepad-friendly numeric keypad for PIN entry

import SwiftUI

// MARK: - NumPadKey Enum

/**
 * Numeric keypad key enumeration
 * @requirement F-022 - 手柄操控 UI/UX 优化
 * @satisfies AC-067 - PIN 输入数字键盘优化
 */
enum NumPadKey: String, CaseIterable, Hashable {
    case digit0 = "0"
    case digit1 = "1"
    case digit2 = "2"
    case digit3 = "3"
    case digit4 = "4"
    case digit5 = "5"
    case digit6 = "6"
    case digit7 = "7"
    case digit8 = "8"
    case digit9 = "9"
    case backspace = "backspace"
    case empty = "empty"

    /// Display value shown on the key
    var displayValue: String {
        switch self {
        case .digit0: return "0"
        case .digit1: return "1"
        case .digit2: return "2"
        case .digit3: return "3"
        case .digit4: return "4"
        case .digit5: return "5"
        case .digit6: return "6"
        case .digit7: return "7"
        case .digit8: return "8"
        case .digit9: return "9"
        case .backspace: return "⌫"
        case .empty: return ""
        }
    }

    /// Whether this key is a digit
    var isDigit: Bool {
        switch self {
        case .digit0, .digit1, .digit2, .digit3, .digit4,
             .digit5, .digit6, .digit7, .digit8, .digit9:
            return true
        default:
            return false
        }
    }

    /// Whether this key is actionable (not empty)
    var isActionable: Bool {
        self != .empty
    }
}

// MARK: - NumPadLayout

/**
 * Numeric keypad layout configuration
 * @requirement F-022 - 手柄操控 UI/UX 优化
 * @satisfies AC-067 - 3×4 网格布局
 */
struct NumPadLayout {
    let rows: [[NumPadKey]]

    /// Standard phone-style layout: 1-2-3, 4-5-6, 7-8-9, empty-0-backspace
    static let standard = NumPadLayout(rows: [
        [.digit1, .digit2, .digit3],
        [.digit4, .digit5, .digit6],
        [.digit7, .digit8, .digit9],
        [.empty, .digit0, .backspace]
    ])

    /// Default focus key (center position)
    static let defaultFocusKey: NumPadKey = .digit5
}

// MARK: - NumPadInputHandler

/**
 * Input handling logic for the numeric keypad
 * @requirement F-022 - 手柄操控 UI/UX 优化
 * @satisfies AC-067 - PIN 输入数字键盘优化
 */
enum NumPadInputHandler {
    /**
     * Handle a key press on the numeric keypad
     * - Parameters:
     *   - key: The key that was pressed
     *   - value: The current input value (inout)
     *   - maxLength: Maximum allowed length
     *   - onComplete: Optional callback when maxLength is reached
     */
    static func handleKeyPress(
        _ key: NumPadKey,
        value: inout String,
        maxLength: Int,
        onComplete: ((String) -> Void)? = nil
    ) {
        switch key {
        case .empty:
            // Empty key does nothing
            return

        case .backspace:
            // Delete last character if not empty
            if !value.isEmpty {
                value.removeLast()
            }

        default:
            // Digit keys - append if under maxLength
            guard key.isDigit else { return }
            guard value.count < maxLength else { return }

            value.append(key.displayValue)

            // Check for completion
            if value.count == maxLength {
                onComplete?(value)
            }
        }
    }
}

// MARK: - GamepadNumPad View

/**
 * Gamepad-friendly numeric keypad view
 * @requirement F-022 - 手柄操控 UI/UX 优化
 * @satisfies AC-067 - PIN 输入数字键盘优化
 */
struct GamepadNumPad: View {
    /// Current input value binding
    @Binding var value: String

    /// Maximum input length (default 4 for PIN)
    let maxLength: Int

    /// Callback when input reaches maxLength
    var onComplete: ((String) -> Void)?

    /// Focus state for the keypad
    @FocusState private var focusedKey: NumPadKey?

    /// Layout configuration
    private let layout = NumPadLayout.standard

    init(value: Binding<String>, maxLength: Int = 4, onComplete: ((String) -> Void)? = nil) {
        self._value = value
        self.maxLength = maxLength
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: keySpacing) {
            ForEach(Array(layout.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: keySpacing) {
                    ForEach(row, id: \.self) { key in
                        NumPadKeyButton(
                            key: key,
                            isFocused: focusedKey == key,
                            action: { handleKeyPress(key) }
                        )
                        .focused($focusedKey, equals: key)
                    }
                }
            }
        }
        .onAppear {
            // Set default focus to center key (5)
            focusedKey = NumPadLayout.defaultFocusKey
        }
    }

    // MARK: - Private Methods

    private func handleKeyPress(_ key: NumPadKey) {
        NumPadInputHandler.handleKeyPress(key, value: &value, maxLength: maxLength, onComplete: onComplete)
    }

    // MARK: - Layout Constants

    private var keySpacing: CGFloat {
        #if os(tvOS)
        return 16
        #else
        return 12
        #endif
    }
}

// MARK: - NumPadKeyButton

/**
 * Individual key button for the numeric keypad
 */
private struct NumPadKeyButton: View {
    let key: NumPadKey
    let isFocused: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(key.displayValue)
                .font(.title)
                .fontWeight(.medium)
                .frame(width: keySize, height: keySize)
                .background(backgroundColor)
                .foregroundStyle(foregroundColor)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay {
                    if isFocused {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.accentColor, lineWidth: 3)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(!key.isActionable)
        .opacity(key.isActionable ? 1.0 : 0.0)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(key.isActionable ? String(localized: "numPad.pressToEnter") : "")
    }

    // MARK: - Styling

    private var keySize: CGFloat {
        #if os(tvOS)
        return 80
        #else
        return 60
        #endif
    }

    private var cornerRadius: CGFloat {
        #if os(tvOS)
        return 16
        #else
        return 12
        #endif
    }

    private var backgroundColor: Color {
        if key == .backspace {
            return Color.red.opacity(0.2)
        }
        #if os(iOS) || os(tvOS)
        return Color(.secondarySystemBackground)
        #else
        return Color.gray.opacity(0.15)
        #endif
    }

    private var foregroundColor: Color {
        if key == .backspace {
            return .red
        }
        return .primary
    }

    private var accessibilityLabel: String {
        switch key {
        case .backspace:
            return String(localized: "numPad.backspace")
        case .empty:
            return ""
        default:
            return key.displayValue
        }
    }
}

// MARK: - PIN Display

/**
 * PIN display with masked/visible toggle
 * @requirement F-022 - 手柄操控 UI/UX 优化
 * @satisfies AC-067 - PIN 显示使用占位符
 */
struct PINDisplay: View {
    let value: String
    let maxLength: Int
    let showValue: Bool

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<maxLength, id: \.self) { index in
                PINDigitView(
                    digit: digit(at: index),
                    isFilled: index < value.count,
                    showValue: showValue
                )
            }
        }
    }

    private func digit(at index: Int) -> String {
        guard index < value.count else { return "" }
        let stringIndex = value.index(value.startIndex, offsetBy: index)
        return String(value[stringIndex])
    }
}

private struct PINDigitView: View {
    let digit: String
    let isFilled: Bool
    let showValue: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFilled ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 2)
                .frame(width: 44, height: 56)

            if isFilled {
                if showValue {
                    Text(digit)
                        .font(.title.monospaced())
                        .fontWeight(.semibold)
                } else {
                    Circle()
                        .fill(Color.primary)
                        .frame(width: 12, height: 12)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("GamepadNumPad") {
    struct PreviewWrapper: View {
        @State private var pin = ""

        var body: some View {
            VStack(spacing: 32) {
                PINDisplay(value: pin, maxLength: 4, showValue: false)

                GamepadNumPad(value: $pin) { finalPin in
                    print("PIN entered: \(finalPin)")
                }

                Text("Current: \(pin)")
                    .font(.caption)
            }
            .padding()
        }
    }

    return PreviewWrapper()
}

#Preview("PINDisplay - Hidden") {
    PINDisplay(value: "12", maxLength: 4, showValue: false)
}

#Preview("PINDisplay - Visible") {
    PINDisplay(value: "1234", maxLength: 4, showValue: true)
}
