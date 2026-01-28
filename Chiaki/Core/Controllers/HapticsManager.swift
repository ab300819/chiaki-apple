// SPDX-License-Identifier: AGPL-3.0-only
//
// HapticsManager.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Centralized manager for semantic haptic feedback across platforms
//

import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import CoreHaptics

/// Manager for semantic haptic feedback providing consistent physical response for app events
@MainActor
final class HapticsManager: Sendable {
    // MARK: - Properties
    
    static let shared = HapticsManager()
    
    private let engine: CHHapticEngine?
    
    // MARK: - Initialization
    
    private init() {
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            do {
                let hapticEngine = try CHHapticEngine()
                try hapticEngine.start()
                self.engine = hapticEngine
                logDebug("HapticsManager: CoreHaptics engine started")
            } catch {
                logWarning("HapticsManager: Failed to start CoreHaptics engine: \(error)")
                self.engine = nil
            }
        } else {
            self.engine = nil
        }
    }
    
    // MARK: - Semantic Feedback
    
    /// Play feedback for successful operations (e.g., connection established)
    func playSuccess() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        #endif
    }
    
    /// Play feedback for warnings (e.g., packet loss detected)
    func playWarning() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        #endif
    }
    
    /// Play feedback for errors (e.g., connection failed)
    func playError() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        #endif
    }
    
    /// Play feedback for subtle selection changes
    func playSelection() {
        #if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        #endif
    }
    
    /// Play impact feedback with specified intensity
    func playImpact(_ style: ImpactStyle = .medium) {
        #if os(iOS)
        let generator: UIImpactFeedbackGenerator
        switch style {
        case .light: generator = UIImpactFeedbackGenerator(style: .light)
        case .medium: generator = UIImpactFeedbackGenerator(style: .medium)
        case .heavy: generator = UIImpactFeedbackGenerator(style: .heavy)
        case .soft: generator = UIImpactFeedbackGenerator(style: .soft)
        case .rigid: generator = UIImpactFeedbackGenerator(style: .rigid)
        }
        generator.impactOccurred()
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        #endif
    }
    
    // MARK: - Custom Patterns
    
    /// Play a custom "heartbeat" pattern for background tasks or waiting
    func playHeartbeat() {
        guard let engine = engine else { return }
        
        do {
            let event1 = CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
            ], relativeTime: 0)
            
            let event2 = CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            ], relativeTime: 0.15)
            
            let pattern = try CHHapticPattern(events: [event1, event2], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            logDebug("HapticsManager: Failed to play heartbeat: \(error)")
        }
    }
    
    // MARK: - Types
    
    enum ImpactStyle: Sendable {
        case light, medium, heavy, soft, rigid
    }
}
