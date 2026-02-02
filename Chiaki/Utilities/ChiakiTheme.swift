// SPDX-License-Identifier: AGPL-3.0-only
//
// ChiakiTheme.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Centralized theme management for brand colors and styling constants

import SwiftUI

/// Chiaki brand theme and styling constants
enum ChiakiTheme {
    // MARK: - Brand Colors
    
    /// Main Chiaki purple brand color (#6750A4)
    static let brandPurple = Color(red: 0.404, green: 0.314, blue: 0.643)
    
    /// Secondary accent color
    static let accent = Color.blue
    
    // MARK: - Semantic Colors
    
    enum Status {
        static let excellent = Color.green
        static let good = Color.green
        static let fair = Color.yellow
        static let poor = Color.red
        static let offline = Color.gray
    }
    
    // MARK: - Layout Constants
    
    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
    }
    
    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 20
    }

    // MARK: - Touch Target Constants

    /**
     * Touch target size constants following Apple HIG guidelines
     * @requirement F-023 - iPad 触摸操作友好化
     * @satisfies AC-069 - 触摸目标尺寸
     */
    enum Touch {
        /// Apple HIG minimum touch target size (44×44pt)
        static let minTargetSize: CGFloat = 44

        /// Minimum spacing between adjacent interactive controls
        static let minSpacing: CGFloat = 16

        /// Recommended touch target size for comfortable interaction
        static let recommendedTargetSize: CGFloat = 48

        /// Slider touch area height
        static let sliderHeight: CGFloat = 44
    }
}

extension Color {
    static let chiakiPurple = ChiakiTheme.brandPurple
}
