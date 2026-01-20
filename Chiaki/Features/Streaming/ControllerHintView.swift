// SPDX-License-Identifier: AGPL-3.0-only
//
// ControllerHintView.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Floating hint overlay for controller shortcuts

import SwiftUI

struct ControllerHintView: View {
    let controllerType: ControllerManager.ControllerHintType

    private var backButton: String {
        switch controllerType {
        case .playstation: return "circle"
        case .xbox: return "b.circle"
        case .generic: return "circle"
        }
    }

    private var menuButton: String {
        switch controllerType {
        case .playstation: return "OPTIONS"
        case .xbox: return "MENU"
        case .generic: return "MENU"
        }
    }
    
    var body: some View {
        HStack(spacing: 20) {
            HintItem(icon: backButton, text: "Back")
            HintItem(icon: "line.3.horizontal", text: menuButton)
            HintItem(icon: "house", text: "PS Home")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

private struct HintItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            if icon.count > 1 && icon.uppercased() == icon {
                Text(icon)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.3))
                    .cornerRadius(4)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
            }
            
            Text(text)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(.white.opacity(0.8))
    }
}

#Preview {
    ZStack {
        Color.black
        ControllerHintView(controllerType: .playstation)
    }
}

// Note: Uses ControllerManager.ControllerHintType from Core/Controllers/ControllerManager.swift
