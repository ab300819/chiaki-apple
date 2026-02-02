// SPDX-License-Identifier: AGPL-3.0-only
//
// FocusableButtonStyle.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// tvOS focused button style

import SwiftUI

/**
 * Custom button style for tvOS to provide visual feedback on focus
 * @requirement F-020 - 手柄操作友好化
 * @satisfies AC-056 - tvOS 焦点视觉反馈
 */
struct FocusableButtonStyle: ButtonStyle {
    #if os(tvOS)
    @Environment(\.isFocused) private var isFocused: Bool
    #endif
    
    let cornerRadius: CGFloat
    
    static let focusedScale: CGFloat = 1.05
    static let unfocusedScale: CGFloat = 1.0
    static let animationDuration: Double = 0.15
    
    init(cornerRadius: CGFloat = 12) {
        self.cornerRadius = cornerRadius
    }
    
    func makeBody(configuration: Configuration) -> some View {
        #if os(tvOS)
        configuration.label
            // AC-056: scaleEffect(1.05) when focused
            .scaleEffect(isFocused ? Self.focusedScale : Self.unfocusedScale)
            // AC-056: accentColor border (lineWidth: 3)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 3)
            )
            // AC-056: shadow when focused
            .shadow(color: isFocused ? Color.accentColor.opacity(0.5) : Color.clear, radius: 10)
            // AC-056: 0.15s easeInOut animation
            .animation(.easeInOut(duration: Self.animationDuration), value: isFocused)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
        #else
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
        #endif
    }
}
