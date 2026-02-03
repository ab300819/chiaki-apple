// SPDX-License-Identifier: AGPL-3.0-only
//
// ControllerManager.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Manages physical game controllers using GameController framework
// Handles DualSense-specific features (haptics, adaptive triggers)

import Foundation
import GameController
import Combine

// MARK: - Controller Info

/// Information about a connected controller
struct ControllerInfo: Identifiable {
    let id: UUID
    let controller: GCController
    var isActive: Bool

    var name: String {
        controller.vendorName ?? "Unknown Controller"
    }

    var productCategory: String {
        controller.productCategory
    }

    var isDualSense: Bool {
        controller.productCategory == GCProductCategoryDualSense
    }

    var isDualShock: Bool {
        controller.productCategory == GCProductCategoryDualShock4
    }

    var isPlayStationController: Bool {
        isDualSense || isDualShock
    }

    init(controller: GCController, isActive: Bool = false) {
        self.id = UUID()
        self.controller = controller
        self.isActive = isActive
    }
}

// MARK: - Controller Manager

/// Manages physical game controllers and converts input to ChiakiControllerInput
/// @requirement F-004 - 控制器支持
/// @satisfies AC-054 - 核心流程日志覆盖
@MainActor
@Observable
final class ControllerManager {
    // MARK: - Properties

    /// All connected controllers
    private(set) var connectedControllers: [ControllerInfo] = []

    /// Currently active controller (primary controller)
    private(set) var activeController: ControllerInfo?

    /// Current controller input state
    private(set) var currentInput = ChiakiControllerInput()

    /// Whether haptic feedback is enabled
    var hapticsEnabled: Bool = true

    /// Whether adaptive triggers are enabled (DualSense)
    var adaptiveTriggersEnabled: Bool = true

    // MARK: - Callbacks

    /// Called when controller input changes
    var onInputChanged: ((ChiakiControllerInput) -> Void)?

    /// Called when rumble feedback should be applied
    var onRumbleReceived: ((UInt8, UInt8) -> Void)?

    // MARK: - Private Properties

    private var notificationObservers: [NSObjectProtocol] = []

    // MARK: - Singleton

    static let shared = ControllerManager()

    // MARK: - Initialization

    private init() {
        setupNotifications()
        scanConnectedControllers()
        Logger.controller.info("ControllerManager initialized")
    }

    // Note: As a singleton, deinit is not expected to be called
    // Notification observers are retained for app lifetime

    // MARK: - Setup

    private func setupNotifications() {
        // Controller connected
        let connectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, let controller = notification.object as? GCController else { return }
            Task { @MainActor in
                self.handleControllerConnected(controller)
            }
        }
        notificationObservers.append(connectObserver)

        // Controller disconnected
        let disconnectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, let controller = notification.object as? GCController else { return }
            Task { @MainActor in
                self.handleControllerDisconnected(controller)
            }
        }
        notificationObservers.append(disconnectObserver)

        // Become current (controller selected)
        let becomeCurrentObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidBecomeCurrent,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, let controller = notification.object as? GCController else { return }
            Task { @MainActor in
                self.setActiveController(controller)
            }
        }
        notificationObservers.append(becomeCurrentObserver)
    }

    private func scanConnectedControllers() {
        for controller in GCController.controllers() {
            handleControllerConnected(controller)
        }

        // Set first PlayStation controller as active, or first controller
        if let psController = connectedControllers.first(where: { $0.isPlayStationController }) {
            setActiveController(psController.controller)
        } else if let firstController = connectedControllers.first {
            setActiveController(firstController.controller)
        }
    }

    // MARK: - Controller Connection

    private func handleControllerConnected(_ controller: GCController) {
        guard !connectedControllers.contains(where: { $0.controller === controller }) else {
            return
        }

        let info = ControllerInfo(controller: controller)
        connectedControllers.append(info)

        Logger.controller.info("Controller connected: \(info.name) (Category: \(info.productCategory), DualSense: \(info.isDualSense))")

        // Setup input handlers
        setupInputHandlers(for: controller)

        // If this is a PlayStation controller and no active controller, make it active
        if activeController == nil && info.isPlayStationController {
            setActiveController(controller)
        } else if activeController == nil {
            setActiveController(controller)
        }
    }

    private func handleControllerDisconnected(_ controller: GCController) {
        guard let index = connectedControllers.firstIndex(where: { $0.controller === controller }) else {
            return
        }

        let info = connectedControllers[index]
        connectedControllers.remove(at: index)

        Logger.controller.info("Controller disconnected: \(info.name)")

        // If active controller disconnected, select another
        if activeController?.controller === controller {
            activeController = nil
            if let nextController = connectedControllers.first {
                setActiveController(nextController.controller)
            }
        }
    }

    // MARK: - Active Controller

    private func setActiveController(_ controller: GCController) {
        // Update isActive flags
        for i in 0..<connectedControllers.count {
            connectedControllers[i].isActive = (connectedControllers[i].controller === controller)
        }

        activeController = connectedControllers.first(where: { $0.controller === controller })

        if let activeController = activeController {
            Logger.controller.info("Active controller: \(activeController.name)")

            // Setup DualSense-specific features
            if activeController.isDualSense {
                setupDualSenseFeatures(controller)
            }
        }
    }

    // MARK: - Input Handling

    private func setupInputHandlers(for controller: GCController) {
        // Extended gamepad (most common)
        if let extendedGamepad = controller.extendedGamepad {
            setupExtendedGamepadHandlers(extendedGamepad)
        }

        // DualSense-specific
        if let dualSense = controller.physicalInputProfile as? GCDualSenseGamepad {
            setupDualSenseHandlers(dualSense)
        }
    }

    private func setupExtendedGamepadHandlers(_ gamepad: GCExtendedGamepad) {
        // Use value changed handler for all inputs
        gamepad.valueChangedHandler = { [weak self] gamepad, element in
            Task { @MainActor in
                self?.handleExtendedGamepadInput(gamepad)
            }
        }
    }

    private func handleExtendedGamepadInput(_ gamepad: GCExtendedGamepad) {
        var input = ChiakiControllerInput()

        // Face buttons
        if gamepad.buttonA.isPressed { input.buttons.insert(.cross) }
        if gamepad.buttonB.isPressed { input.buttons.insert(.moon) }
        if gamepad.buttonX.isPressed { input.buttons.insert(.box) }
        if gamepad.buttonY.isPressed { input.buttons.insert(.pyramid) }

        // Shoulder buttons
        if gamepad.leftShoulder.isPressed { input.buttons.insert(.l1) }
        if gamepad.rightShoulder.isPressed { input.buttons.insert(.r1) }

        // Triggers (analog)
        input.l2 = UInt8(gamepad.leftTrigger.value * 255)
        input.r2 = UInt8(gamepad.rightTrigger.value * 255)

        // D-pad
        if gamepad.dpad.up.isPressed { input.buttons.insert(.dpadUp) }
        if gamepad.dpad.down.isPressed { input.buttons.insert(.dpadDown) }
        if gamepad.dpad.left.isPressed { input.buttons.insert(.dpadLeft) }
        if gamepad.dpad.right.isPressed { input.buttons.insert(.dpadRight) }

        // Sticks
        input.leftStickX = Int16(gamepad.leftThumbstick.xAxis.value * 32767)
        input.leftStickY = Int16(gamepad.leftThumbstick.yAxis.value * 32767)
        input.rightStickX = Int16(gamepad.rightThumbstick.xAxis.value * 32767)
        input.rightStickY = Int16(gamepad.rightThumbstick.yAxis.value * 32767)

        // Stick buttons
        if let leftThumbstickButton = gamepad.leftThumbstickButton, leftThumbstickButton.isPressed {
            input.buttons.insert(.l3)
        }
        if let rightThumbstickButton = gamepad.rightThumbstickButton, rightThumbstickButton.isPressed {
            input.buttons.insert(.r3)
        }

        // Options/Menu buttons
        if gamepad.buttonOptions?.isPressed == true { input.buttons.insert(.share) }
        if gamepad.buttonMenu.isPressed { input.buttons.insert(.options) }
        if gamepad.buttonHome?.isPressed == true { input.buttons.insert(.ps) }

        // Update state and notify
        currentInput = input
        onInputChanged?(input)
    }

    // MARK: - DualSense Features

    private func setupDualSenseHandlers(_ dualSense: GCDualSenseGamepad) {
        // Touchpad button
        dualSense.touchpadButton.valueChangedHandler = { [weak self] button, value, pressed in
            Task { @MainActor in
                if pressed {
                    self?.currentInput.buttons.insert(.touchpad)
                } else {
                    self?.currentInput.buttons.remove(.touchpad)
                }
                if let input = self?.currentInput {
                    self?.onInputChanged?(input)
                }
            }
        }

        // Touchpad position tracking
        setupTouchpadInput(dualSense)

        Logger.controller.debug("DualSense handlers configured with touchpad tracking")
    }

    // MARK: - Touchpad Position Tracking

    /// Setup touchpad input handlers for DualSense controller
    /// @requirement F-021 - GameController 深度集成
    /// @satisfies AC-062 - 触控板位置追踪
    private func setupTouchpadInput(_ dualSense: GCDualSenseGamepad) {
        // Primary touch (finger 1)
        dualSense.touchpadPrimary.valueChangedHandler = { [weak self] dpad, xValue, yValue in
            Task { @MainActor in
                self?.handleTouchpadInput(touchId: 0, xValue: xValue, yValue: yValue, dpad: dpad)
            }
        }

        // Secondary touch (finger 2)
        dualSense.touchpadSecondary.valueChangedHandler = { [weak self] dpad, xValue, yValue in
            Task { @MainActor in
                self?.handleTouchpadInput(touchId: 1, xValue: xValue, yValue: yValue, dpad: dpad)
            }
        }

        Logger.controller.debug("Touchpad position tracking enabled")
    }

    /// Handle touchpad input update
    /// - Parameters:
    ///   - touchId: Touch point identifier (0 for primary, 1 for secondary)
    ///   - xValue: X axis value from GCControllerDirectionPad (-1.0 to 1.0)
    ///   - yValue: Y axis value from GCControllerDirectionPad (-1.0 to 1.0)
    ///   - dpad: The direction pad element for touch state checking
    private func handleTouchpadInput(touchId: Int, xValue: Float, yValue: Float, dpad: GCControllerDirectionPad) {
        // GCControllerDirectionPad reports values in -1.0 to 1.0 range
        // We need to normalize to 0.0 to 1.0 range
        let normalizedX = (xValue + 1.0) / 2.0
        let normalizedY = (yValue + 1.0) / 2.0

        // Determine if touch is active (any axis is non-zero or buttons pressed)
        let isActive = xValue != 0 || yValue != 0 ||
                       dpad.up.isPressed || dpad.down.isPressed ||
                       dpad.left.isPressed || dpad.right.isPressed

        let touchPoint = TouchPoint(id: touchId, x: normalizedX, y: normalizedY, isActive: isActive)

        // Update touchpad array
        updateTouchpadState(touchPoint)

        // Notify input changed
        onInputChanged?(currentInput)
    }

    /// Update the touchpad state with a new touch point
    /// - Parameter touchPoint: The touch point to update
    private func updateTouchpadState(_ touchPoint: TouchPoint) {
        // Find existing touch point with same ID or add new one
        if let index = currentInput.touchpad.firstIndex(where: { $0.id == touchPoint.id }) {
            if touchPoint.isActive {
                currentInput.touchpad[index] = touchPoint
            } else {
                // Remove inactive touch points
                currentInput.touchpad.remove(at: index)
            }
        } else if touchPoint.isActive {
            // Only add if active and within max touches limit
            if currentInput.touchpad.count < TouchpadConstants.maxTouches {
                currentInput.touchpad.append(touchPoint)
            }
        }

        // Sort by ID for consistent ordering
        currentInput.touchpad.sort { $0.id < $1.id }
    }

    private func setupDualSenseFeatures(_ controller: GCController) {
        // Start haptic engine via shared manager
        startHaptics()
        Logger.controller.debug("DualSense features configured, haptics delegated to HapticsManager")
    }

    // MARK: - Adaptive Triggers

    /// Current adaptive trigger state
    private(set) var adaptiveTriggerState = AdaptiveTriggerState()

    /// Apply adaptive trigger effect to the active DualSense controller
    /// @requirement F-021 - GameController 深度集成
    /// @satisfies AC-061 - DualSense 自适应扳机支持
    /// - Parameters:
    ///   - effect: The trigger effect to apply
    ///   - side: Which trigger to apply the effect to
    func applyAdaptiveTrigger(effect: AdaptiveTriggerEffect, side: TriggerSide) {
        guard adaptiveTriggersEnabled else {
            Logger.controller.debug("Adaptive triggers disabled, ignoring effect")
            return
        }

        guard let controller = activeController?.controller,
              let dualSense = controller.physicalInputProfile as? GCDualSenseGamepad else {
            // Silently ignore for non-DualSense controllers
            return
        }

        let trigger: GCDualSenseAdaptiveTrigger = side == .left
            ? dualSense.leftTrigger
            : dualSense.rightTrigger

        applyEffectToTrigger(effect, trigger: trigger)

        // Update state
        switch side {
        case .left:
            adaptiveTriggerState.leftEffect = effect
        case .right:
            adaptiveTriggerState.rightEffect = effect
        }

        Logger.controller.debug("Applied adaptive trigger: \(side.rawValue) = \(effect.description)")
    }

    /// Apply effects to both triggers at once
    /// @requirement F-021 - GameController 深度集成
    /// @satisfies AC-061 - DualSense 自适应扳机支持
    func applyAdaptiveTriggers(left: AdaptiveTriggerEffect, right: AdaptiveTriggerEffect) {
        applyAdaptiveTrigger(effect: left, side: .left)
        applyAdaptiveTrigger(effect: right, side: .right)
    }

    /// Reset both adaptive triggers to off
    /// @satisfies AC-061 - DualSense 自适应扳机支持
    func resetAdaptiveTriggers() {
        applyAdaptiveTriggers(left: .off, right: .off)
        adaptiveTriggerState.reset()
        Logger.controller.debug("Adaptive triggers reset to off")
    }

    /// Apply the effect to a specific GCDualSenseAdaptiveTrigger
    /// Uses the GCDualSenseAdaptiveTrigger API (iOS 14.5+ / macOS 11.3+)
    private func applyEffectToTrigger(_ effect: AdaptiveTriggerEffect, trigger: GCDualSenseAdaptiveTrigger) {
        switch effect {
        case .off:
            trigger.setModeOff()

        case let .feedback(startPosition, strength):
            trigger.setModeFeedbackWithStartPosition(startPosition, resistiveStrength: strength)

        case let .weapon(startPosition, endPosition, strength):
            trigger.setModeWeaponWithStartPosition(startPosition, endPosition: endPosition, resistiveStrength: strength)

        case let .vibration(position, amplitude, frequency):
            trigger.setModeVibrationWithStartPosition(position, amplitude: amplitude, frequency: frequency)
        }
    }

    // MARK: - Haptic Feedback

    /// Start haptic engine (delegates to HapticsManager)
    /// @satisfies AC-063 - Haptics 引擎统一
    func startHaptics() {
        HapticsManager.shared.startEngine()
    }

    /// Stop haptic engine (delegates to HapticsManager)
    /// @satisfies AC-063 - Haptics 引擎统一
    func stopHaptics() {
        HapticsManager.shared.stopEngine()
    }

    /// Apply rumble feedback to the active controller (delegates to HapticsManager)
    /// @satisfies AC-063 - Haptics 引擎统一
    func applyRumble(left: UInt8, right: UInt8) {
        guard hapticsEnabled else { return }
        HapticsManager.shared.applyRumble(left: left, right: right)
    }

    // MARK: - LED Control

    /// Set controller LED color (DualSense/DualShock 4)
    func setLEDColor(r: UInt8, g: UInt8, b: UInt8) {
        guard let controller = activeController?.controller else { return }

        if let light = controller.light {
            light.color = GCColor(
                red: Float(r) / 255.0,
                green: Float(g) / 255.0,
                blue: Float(b) / 255.0
            )
        }
    }

    // MARK: - Player Index

    /// Set player index LED
    func setPlayerIndex(_ index: Int) {
        guard let controller = activeController?.controller else { return }
        controller.playerIndex = GCControllerPlayerIndex(rawValue: index) ?? .indexUnset
    }

    // MARK: - Motion Data

    /// Enable motion data collection
    func enableMotion() {
        guard let controller = activeController?.controller,
              let motion = controller.motion else { return }

        motion.sensorsActive = true
        motion.valueChangedHandler = { [weak self] motion in
            Task { @MainActor in
                self?.handleMotionUpdate(motion)
            }
        }

        Logger.controller.debug("Motion sensors enabled")
    }

    /// Disable motion data collection
    func disableMotion() {
        guard let controller = activeController?.controller,
              let motion = controller.motion else { return }

        motion.sensorsActive = false
        motion.valueChangedHandler = nil
    }

    private func handleMotionUpdate(_ motion: GCMotion) {
        // Update gyro (rotation rate)
        currentInput.gyroX = Float(motion.rotationRate.x)
        currentInput.gyroY = Float(motion.rotationRate.y)
        currentInput.gyroZ = Float(motion.rotationRate.z)

        // Update accelerometer
        currentInput.accelX = Float(motion.acceleration.x)
        currentInput.accelY = Float(motion.acceleration.y)
        currentInput.accelZ = Float(motion.acceleration.z)

        // Update orientation (quaternion)
        currentInput.orientX = Float(motion.attitude.x)
        currentInput.orientY = Float(motion.attitude.y)
        currentInput.orientZ = Float(motion.attitude.z)
        currentInput.orientW = Float(motion.attitude.w)

        onInputChanged?(currentInput)
    }

    // MARK: - Statistics

    var controllerCount: Int {
        connectedControllers.count
    }

    var hasPlayStationController: Bool {
        connectedControllers.contains(where: { $0.isPlayStationController })
    }

    var hasDualSense: Bool {
        connectedControllers.contains(where: { $0.isDualSense })
    }

    /// Detected controller type for UI hints
    var detectedControllerType: ControllerHintType {
        guard let active = activeController else {
            return .generic
        }

        if active.isPlayStationController {
            return .playstation
        }

        // Check for Xbox controllers
        let category = active.productCategory.lowercased()
        if category.contains("xbox") || category.contains("microsoft") {
            return .xbox
        }

        return .generic
    }

    /// Controller type for UI hint display
    enum ControllerHintType {
        case playstation
        case xbox
        case generic
    }
}
