// SPDX-License-Identifier: AGPL-3.0-only
//
// ControllerInputProvider.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Core protocols and types for the controller provider architecture.
// Defines the abstraction layer between input sources and the orchestrator.

import Foundation

// MARK: - Controller Capabilities

/// Capability flags indicating what a controller input provider supports.
/// @requirement F-040 - 控制器架构分层重构
/// @satisfies AC-151 - ControllerInputProvider 协议定义
struct ControllerCapabilities: OptionSet, Sendable {
    let rawValue: UInt16

    /// Standard face buttons, d-pad, shoulder buttons, options/share
    static let standardButtons  = ControllerCapabilities(rawValue: 1 << 0)
    /// Analog thumbsticks (left + right)
    static let analogSticks     = ControllerCapabilities(rawValue: 1 << 1)
    /// Analog triggers (L2/R2 with variable pressure)
    static let analogTriggers   = ControllerCapabilities(rawValue: 1 << 2)
    /// PS button (home button)
    static let psButton         = ControllerCapabilities(rawValue: 1 << 3)
    /// Touchpad input (DualSense/DualShock 4)
    static let touchpad         = ControllerCapabilities(rawValue: 1 << 4)
    /// Motion sensors (gyroscope + accelerometer)
    static let motion           = ControllerCapabilities(rawValue: 1 << 5)
    /// Rumble / haptic feedback output
    static let rumble           = ControllerCapabilities(rawValue: 1 << 6)
    /// DualSense adaptive trigger effects
    static let adaptiveTriggers = ControllerCapabilities(rawValue: 1 << 7)
    /// LED color control
    static let ledColor         = ControllerCapabilities(rawValue: 1 << 8)

    // MARK: - Convenience Presets

    /// Capabilities available through GameController framework (standard controller)
    static let gameController: ControllerCapabilities = [
        .standardButtons, .analogSticks, .analogTriggers,
        .touchpad, .motion, .rumble, .adaptiveTriggers, .ledColor
    ]

    /// Capabilities available through DualSense HID on macOS
    /// PS button and rumble via direct IOKit, plus adaptive triggers and LED
    static let dualSenseHID: ControllerCapabilities = [
        .psButton, .rumble, .adaptiveTriggers, .ledColor
    ]

    /// Capabilities available through DualShock 4 HID on macOS
    static let dualShock4HID: ControllerCapabilities = [
        .psButton, .rumble, .ledColor
    ]
}

// MARK: - Feedback Type

/// Types of feedback that can be sent to a controller.
/// @requirement F-040 - 控制器架构分层重构
/// @satisfies AC-151 - ControllerInputProvider 协议定义
enum FeedbackType: Sendable {
    /// Dual-motor rumble (left = low frequency, right = high frequency)
    case rumble
    /// DualSense adaptive trigger effects
    case adaptiveTrigger
    /// Controller LED color
    case ledColor
}

// MARK: - Controller Input Provider Protocol

/// Protocol for objects that provide controller input to the orchestrator.
/// Each provider represents a single input source (GameController, HID device, etc.)
/// @requirement F-040 - 控制器架构分层重构
/// @satisfies AC-151 - ControllerInputProvider 协议定义
protocol ControllerInputProvider: AnyObject {
    /// Unique identifier for this provider instance
    var providerId: String { get }

    /// Human-readable display name
    var displayName: String { get }

    /// Whether the provider currently has a connected device
    var isConnected: Bool { get }

    /// Capabilities supported by this provider
    var capabilities: ControllerCapabilities { get }

    /// Most recent input state from this provider
    var currentInput: ChiakiControllerInput { get }

    /// Called when input state changes
    var onInputChanged: ((ChiakiControllerInput) -> Void)? { get set }

    /// Called when connection state changes (true = connected, false = disconnected)
    var onConnectionChanged: ((Bool) -> Void)? { get set }

    /// Start monitoring for input
    func start()

    /// Stop monitoring and release resources
    func stop()
}

// MARK: - Controller Feedback Output Protocol

/// Protocol for objects that can receive feedback commands (rumble, triggers, LED).
/// A provider may implement both ControllerInputProvider and ControllerFeedbackOutput.
/// @requirement F-040 - 控制器架构分层重构
/// @satisfies AC-151 - ControllerInputProvider 协议定义
protocol ControllerFeedbackOutput: AnyObject {
    /// Send rumble feedback
    /// - Parameters:
    ///   - left: Left motor intensity (0-255, low frequency / heavy)
    ///   - right: Right motor intensity (0-255, high frequency / light)
    func sendRumble(left: UInt8, right: UInt8)

    /// Apply adaptive trigger effect (DualSense only)
    /// - Parameters:
    ///   - effect: The trigger effect to apply
    ///   - side: Which trigger (left or right)
    func applyAdaptiveTrigger(effect: AdaptiveTriggerEffect, side: TriggerSide)

    /// Set LED color on the controller
    /// - Parameters:
    ///   - red: Red component (0-255)
    ///   - green: Green component (0-255)
    ///   - blue: Blue component (0-255)
    func setLEDColor(red: UInt8, green: UInt8, blue: UInt8)

    /// Check if a specific feedback type is supported
    /// - Parameter type: The feedback type to check
    /// - Returns: true if the feedback type is supported
    func supportsFeedback(_ type: FeedbackType) -> Bool
}
