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
}

extension Color {
    static let chiakiPurple = ChiakiTheme.brandPurple
}
