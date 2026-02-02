// SPDX-License-Identifier: AGPL-3.0-only
//
// AdaptiveTriggerEffect.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// DualSense adaptive trigger effect definitions

import Foundation

// MARK: - TriggerSide

/**
 * Represents which trigger to apply the effect to
 * @requirement F-021 - GameController 深度集成
 * @satisfies AC-061 - DualSense 自适应扳机支持
 */
enum TriggerSide: String, CaseIterable, Sendable {
    case left
    case right
}

// MARK: - AdaptiveTriggerEffect

/**
 * Adaptive trigger effect types for DualSense controller
 * @requirement F-021 - GameController 深度集成
 * @satisfies AC-061 - DualSense 自适应扳机支持
 *
 * Based on Apple's GCDualSenseAdaptiveTrigger API (iOS 16+ / macOS 13+):
 * - off: No effect, trigger operates normally
 * - feedback: Constant resistance from a start position
 * - weapon: Variable resistance with defined start/end positions (like pulling a trigger)
 * - vibration: Oscillating feedback at a position with amplitude and frequency
 */
enum AdaptiveTriggerEffect: Sendable, Equatable {
    /// No effect, trigger operates normally
    case off

    /// Constant resistance feedback from a start position
    /// - startPosition: Normalized 0.0~1.0, where effect begins
    /// - strength: Normalized 0.0~1.0, resistance intensity
    case feedback(startPosition: Float, strength: Float)

    /// Weapon-like effect with defined resistance range
    /// - startPosition: Normalized 0.0~1.0, where resistance begins
    /// - endPosition: Normalized 0.0~1.0, where resistance ends (must be > startPosition)
    /// - strength: Normalized 0.0~1.0, resistance intensity
    case weapon(startPosition: Float, endPosition: Float, strength: Float)

    /// Vibration effect at a specific position
    /// - position: Normalized 0.0~1.0, center of vibration
    /// - amplitude: Normalized 0.0~1.0, vibration intensity
    /// - frequency: Normalized 0.0~1.0, vibration speed
    case vibration(position: Float, amplitude: Float, frequency: Float)

    // MARK: - Convenience Properties

    /// Whether this effect is active (not off)
    var isActive: Bool {
        if case .off = self {
            return false
        }
        return true
    }

    /// Human-readable description for logging
    var description: String {
        switch self {
        case .off:
            return "off"
        case let .feedback(start, strength):
            return "feedback(start: \(String(format: "%.2f", start)), strength: \(String(format: "%.2f", strength)))"
        case let .weapon(start, end, strength):
            return "weapon(start: \(String(format: "%.2f", start)), end: \(String(format: "%.2f", end)), strength: \(String(format: "%.2f", strength)))"
        case let .vibration(pos, amp, freq):
            return "vibration(pos: \(String(format: "%.2f", pos)), amp: \(String(format: "%.2f", amp)), freq: \(String(format: "%.2f", freq)))"
        }
    }
}

// MARK: - AdaptiveTriggerState

/**
 * Tracks the current state of both adaptive triggers
 * @requirement F-021 - GameController 深度集成
 * @satisfies AC-061 - DualSense 自适应扳机支持
 */
struct AdaptiveTriggerState: Sendable, Equatable {
    var leftEffect: AdaptiveTriggerEffect = .off
    var rightEffect: AdaptiveTriggerEffect = .off

    /// Whether any trigger has an active effect
    var hasActiveEffect: Bool {
        leftEffect.isActive || rightEffect.isActive
    }

    /// Reset both triggers to off
    mutating func reset() {
        leftEffect = .off
        rightEffect = .off
    }
}
