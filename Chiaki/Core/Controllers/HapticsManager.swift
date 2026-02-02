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
/// @requirement F-021 - GameController 深度集成
/// @satisfies AC-063 - Haptics 引擎统一
@MainActor
final class HapticsManager: Sendable {
    // MARK: - Properties

    static let shared = HapticsManager()

    private var engine: CHHapticEngine?

    /// Whether the haptic engine is currently running
    private(set) var isEngineRunning: Bool = false

    /// Whether the device supports haptics
    let supportsHaptics: Bool

    // MARK: - Initialization

    private init() {
        self.supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

        if supportsHaptics {
            do {
                let hapticEngine = try CHHapticEngine()
                self.engine = hapticEngine
                setupEngineHandlers(hapticEngine)
                try hapticEngine.start()
                self.isEngineRunning = true
                logDebug("HapticsManager: CoreHaptics engine initialized and started")
            } catch {
                logWarning("HapticsManager: Failed to initialize CoreHaptics engine: \(error)")
                self.engine = nil
            }
        } else {
            self.engine = nil
        }
    }

    private func setupEngineHandlers(_ engine: CHHapticEngine) {
        // Handle engine reset (e.g., after app returns from background)
        engine.resetHandler = { [weak self] in
            Task { @MainActor in
                self?.handleEngineReset()
            }
        }

        // Handle engine stopped unexpectedly
        engine.stoppedHandler = { [weak self] reason in
            Task { @MainActor in
                self?.handleEngineStopped(reason: reason)
            }
        }
    }

    private func handleEngineReset() {
        logDebug("HapticsManager: Engine reset, restarting...")
        do {
            try engine?.start()
            isEngineRunning = true
            logDebug("HapticsManager: Engine restarted successfully")
        } catch {
            logWarning("HapticsManager: Failed to restart engine: \(error)")
            isEngineRunning = false
        }
    }

    private func handleEngineStopped(reason: CHHapticEngine.StoppedReason) {
        logDebug("HapticsManager: Engine stopped with reason: \(reason)")
        isEngineRunning = false
    }

    // MARK: - Engine Lifecycle

    /// Start the haptic engine (idempotent - safe to call multiple times)
    func startEngine() {
        guard supportsHaptics, !isEngineRunning else { return }

        do {
            try engine?.start()
            isEngineRunning = true
            logDebug("HapticsManager: Engine started")
        } catch {
            logWarning("HapticsManager: Failed to start engine: \(error)")
        }
    }

    /// Stop the haptic engine
    func stopEngine() {
        guard isEngineRunning else { return }

        engine?.stop(completionHandler: { [weak self] error in
            Task { @MainActor in
                if let error = error {
                    logWarning("HapticsManager: Error stopping engine: \(error)")
                } else {
                    self?.isEngineRunning = false
                    logDebug("HapticsManager: Engine stopped")
                }
            }
        })
    }

    // MARK: - Controller Rumble

    /// Apply rumble feedback with left and right motor intensities
    /// - Parameters:
    ///   - left: Left motor intensity (0-255)
    ///   - right: Right motor intensity (0-255)
    func applyRumble(left: UInt8, right: UInt8) {
        guard supportsHaptics, isEngineRunning, let engine = engine else { return }

        // Normalize UInt8 (0-255) to Float (0.0-1.0)
        let leftIntensity = normalizeIntensity(left)
        let rightIntensity = normalizeIntensity(right)

        // Skip if both are zero
        guard leftIntensity > 0 || rightIntensity > 0 else { return }

        // Create combined rumble pattern
        let combinedIntensity = max(leftIntensity, rightIntensity)
        playRumblePattern(engine: engine, intensity: combinedIntensity)
    }

    /// Normalize UInt8 (0-255) to Float (0.0-1.0)
    func normalizeIntensity(_ value: UInt8) -> Float {
        Float(value) / 255.0
    }

    private func playRumblePattern(engine: CHHapticEngine, intensity: Float) {
        do {
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0,
                duration: 0.1
            )

            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            logDebug("HapticsManager: Rumble playback failed: \(error)")
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
