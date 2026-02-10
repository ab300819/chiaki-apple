// SPDX-License-Identifier: AGPL-3.0-only
//
// GameControllerProvider.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Wraps a GCController as a ControllerInputProvider + ControllerFeedbackOutput.
// Handles extended gamepad input, DualSense touchpad, motion, rumble, and LED.

import Foundation
import GameController
import CoreHaptics

/// Wraps a GCController instance as a unified input provider and feedback output.
/// Handles all GameController framework interactions for a single physical controller.
/// @requirement F-040 - 控制器架构分层重构
/// @satisfies AC-151 - ControllerInputProvider 协议実装
/// @satisfies AC-157 - 回帰テスト通過
@MainActor
final class GameControllerProvider: ControllerInputProvider, ControllerFeedbackOutput {

    // MARK: - ControllerInputProvider

    let providerId: String
    var displayName: String { controller?.vendorName ?? "Unknown Controller" }
    var isConnected: Bool { controller != nil }

    var capabilities: ControllerCapabilities {
        guard let controller else { return [] }
        var caps: ControllerCapabilities = [.standardButtons, .analogSticks, .analogTriggers]

        if controller.physicalInputProfile is GCDualSenseGamepad {
            caps.insert(.touchpad)
            caps.insert(.adaptiveTriggers)
        }
        if controller.motion != nil {
            caps.insert(.motion)
        }
        if controller.haptics != nil {
            caps.insert(.rumble)
        }
        if controller.light != nil {
            caps.insert(.ledColor)
        }
        return caps
    }

    private(set) var currentInput = ChiakiControllerInput()

    var onInputChanged: ((ChiakiControllerInput) -> Void)?
    var onConnectionChanged: ((Bool) -> Void)?

    // MARK: - Private Properties

    private(set) var controller: GCController?
    private var rumbleEngine: CHHapticEngine?

    // MARK: - Initialization

    init(providerId: String = UUID().uuidString) {
        self.providerId = providerId
    }

    // MARK: - Bind / Unbind

    /// Bind this provider to a GCController and set up input handlers.
    func bind(to controller: GCController) {
        self.controller = controller
        setupInputHandlers(controller)
        onConnectionChanged?(true)
        Logger.controller.info("GameControllerProvider bound to: \(controller.vendorName ?? "unknown")")
    }

    /// Unbind from the current controller and release resources.
    func unbind() {
        guard let controller else { return }
        // Clear handlers to avoid stale callbacks
        controller.extendedGamepad?.valueChangedHandler = nil
        controller.extendedGamepad?.buttonHome?.pressedChangedHandler = nil
        if let ds = controller.physicalInputProfile as? GCDualSenseGamepad {
            ds.touchpadButton.valueChangedHandler = nil
            ds.touchpadPrimary.valueChangedHandler = nil
            ds.touchpadSecondary.valueChangedHandler = nil
        }
        if let motion = controller.motion {
            motion.sensorsActive = false
            motion.valueChangedHandler = nil
        }
        rumbleEngine = nil
        self.controller = nil
        currentInput = ChiakiControllerInput()
        onConnectionChanged?(false)
        Logger.controller.info("GameControllerProvider unbound")
    }

    // MARK: - ControllerInputProvider

    func start() {
        // Input handlers are set up in bind(to:)
    }

    func stop() {
        unbind()
    }

    // MARK: - Input Handlers

    private func setupInputHandlers(_ controller: GCController) {
        if let gamepad = controller.extendedGamepad {
            setupExtendedGamepadHandlers(gamepad)
        }
        if let dualSense = controller.physicalInputProfile as? GCDualSenseGamepad {
            setupDualSenseHandlers(dualSense)
        }
    }

    private func setupExtendedGamepadHandlers(_ gamepad: GCExtendedGamepad) {
        gamepad.valueChangedHandler = { [weak self] gamepad, _ in
            Task { @MainActor in
                self?.handleExtendedGamepadInput(gamepad)
            }
        }

        // buttonHome needs dedicated handler — may not trigger valueChangedHandler
        gamepad.buttonHome?.pressedChangedHandler = { [weak self] _, _, pressed in
            Task { @MainActor in
                if pressed {
                    self?.currentInput.buttons.insert(.ps)
                } else {
                    self?.currentInput.buttons.remove(.ps)
                }
                if let input = self?.currentInput {
                    self?.onInputChanged?(input)
                }
            }
        }
    }

    /// Map GCExtendedGamepad state to ChiakiControllerInput.
    /// Y axis is negated: GCController Y+ is up, PlayStation Y+ is down.
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

        // Analog triggers
        input.l2 = UInt8(gamepad.leftTrigger.value * 255)
        input.r2 = UInt8(gamepad.rightTrigger.value * 255)

        // D-pad
        if gamepad.dpad.up.isPressed { input.buttons.insert(.dpadUp) }
        if gamepad.dpad.down.isPressed { input.buttons.insert(.dpadDown) }
        if gamepad.dpad.left.isPressed { input.buttons.insert(.dpadLeft) }
        if gamepad.dpad.right.isPressed { input.buttons.insert(.dpadRight) }

        // Sticks (negate Y: GCController Y+ up → PlayStation Y+ down)
        input.leftStickX = Int16(gamepad.leftThumbstick.xAxis.value * 32767)
        input.leftStickY = Int16(gamepad.leftThumbstick.yAxis.value * -32767)
        input.rightStickX = Int16(gamepad.rightThumbstick.xAxis.value * 32767)
        input.rightStickY = Int16(gamepad.rightThumbstick.yAxis.value * -32767)

        // Stick buttons
        if let l3 = gamepad.leftThumbstickButton, l3.isPressed { input.buttons.insert(.l3) }
        if let r3 = gamepad.rightThumbstickButton, r3.isPressed { input.buttons.insert(.r3) }

        // Options/Menu
        if gamepad.buttonOptions?.isPressed == true { input.buttons.insert(.share) }
        if gamepad.buttonMenu.isPressed { input.buttons.insert(.options) }
        if gamepad.buttonHome?.isPressed == true { input.buttons.insert(.ps) }

        currentInput = input
        onInputChanged?(input)
    }

    // MARK: - DualSense Handlers

    private func setupDualSenseHandlers(_ dualSense: GCDualSenseGamepad) {
        dualSense.touchpadButton.valueChangedHandler = { [weak self] _, _, pressed in
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

        dualSense.touchpadPrimary.valueChangedHandler = { [weak self] dpad, xValue, yValue in
            Task { @MainActor in
                self?.handleTouchpadInput(touchId: 0, xValue: xValue, yValue: yValue, dpad: dpad)
            }
        }

        dualSense.touchpadSecondary.valueChangedHandler = { [weak self] dpad, xValue, yValue in
            Task { @MainActor in
                self?.handleTouchpadInput(touchId: 1, xValue: xValue, yValue: yValue, dpad: dpad)
            }
        }
    }

    private func handleTouchpadInput(touchId: Int, xValue: Float, yValue: Float, dpad: GCControllerDirectionPad) {
        let normalizedX = (xValue + 1.0) / 2.0
        let normalizedY = (yValue + 1.0) / 2.0

        let isActive = xValue != 0 || yValue != 0 ||
                       dpad.up.isPressed || dpad.down.isPressed ||
                       dpad.left.isPressed || dpad.right.isPressed

        let touchPoint = TouchPoint(id: touchId, x: normalizedX, y: normalizedY, isActive: isActive)

        if let index = currentInput.touchpad.firstIndex(where: { $0.id == touchPoint.id }) {
            if touchPoint.isActive {
                currentInput.touchpad[index] = touchPoint
            } else {
                currentInput.touchpad.remove(at: index)
            }
        } else if touchPoint.isActive {
            if currentInput.touchpad.count < TouchpadConstants.maxTouches {
                currentInput.touchpad.append(touchPoint)
            }
        }
        currentInput.touchpad.sort { $0.id < $1.id }
        onInputChanged?(currentInput)
    }

    // MARK: - Motion

    /// Enable motion data collection from the bound controller.
    func enableMotion() {
        guard let motion = controller?.motion else { return }
        motion.sensorsActive = true
        motion.valueChangedHandler = { [weak self] motion in
            Task { @MainActor in
                self?.handleMotionUpdate(motion)
            }
        }
    }

    /// Disable motion data collection.
    func disableMotion() {
        guard let motion = controller?.motion else { return }
        motion.sensorsActive = false
        motion.valueChangedHandler = nil
    }

    private func handleMotionUpdate(_ motion: GCMotion) {
        currentInput.gyroX = Float(motion.rotationRate.x)
        currentInput.gyroY = Float(motion.rotationRate.y)
        currentInput.gyroZ = Float(motion.rotationRate.z)
        currentInput.accelX = Float(motion.acceleration.x)
        currentInput.accelY = Float(motion.acceleration.y)
        currentInput.accelZ = Float(motion.acceleration.z)
        currentInput.orientX = Float(motion.attitude.x)
        currentInput.orientY = Float(motion.attitude.y)
        currentInput.orientZ = Float(motion.attitude.z)
        currentInput.orientW = Float(motion.attitude.w)
        onInputChanged?(currentInput)
    }

    // MARK: - ControllerFeedbackOutput

    func sendRumble(left: UInt8, right: UInt8) {
        guard let haptics = controller?.haptics else { return }

        let leftIntensity = Float(left) / 255.0
        let rightIntensity = Float(right) / 255.0
        let intensity = max(leftIntensity, rightIntensity)

        if let engine = rumbleEngine {
            playRumblePattern(engine: engine, intensity: intensity)
        } else if let engine = try? haptics.createEngine(withLocality: .handles) {
            rumbleEngine = engine
            engine.resetHandler = { [weak self] in
                Task { @MainActor in self?.rumbleEngine = nil }
            }
            engine.stoppedHandler = { [weak self] _ in
                Task { @MainActor in self?.rumbleEngine = nil }
            }
            do {
                try engine.start()
                playRumblePattern(engine: engine, intensity: intensity)
            } catch {
                Logger.controller.error("Failed to start GC rumble engine: \(error)")
                rumbleEngine = nil
            }
        }
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
            Logger.controller.debug("GC rumble pattern failed: \(error)")
        }
    }

    func applyAdaptiveTrigger(effect: AdaptiveTriggerEffect, side: TriggerSide) {
        guard let dualSense = controller?.physicalInputProfile as? GCDualSenseGamepad else { return }

        let trigger: GCDualSenseAdaptiveTrigger = side == .left
            ? dualSense.leftTrigger
            : dualSense.rightTrigger

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

    func setLEDColor(red: UInt8, green: UInt8, blue: UInt8) {
        guard let light = controller?.light else { return }
        light.color = GCColor(
            red: Float(red) / 255.0,
            green: Float(green) / 255.0,
            blue: Float(blue) / 255.0
        )
    }

    func supportsFeedback(_ type: FeedbackType) -> Bool {
        switch type {
        case .rumble: return capabilities.contains(.rumble)
        case .adaptiveTrigger: return capabilities.contains(.adaptiveTriggers)
        case .ledColor: return capabilities.contains(.ledColor)
        }
    }

    // MARK: - Controller Info

    /// Product category from GCController
    var productCategory: String { controller?.productCategory ?? "" }

    /// Whether the bound controller is a DualSense
    var isDualSense: Bool { controller?.productCategory == GCProductCategoryDualSense }

    /// Whether the bound controller is a DualShock 4
    var isDualShock4: Bool { controller?.productCategory == GCProductCategoryDualShock4 }

    /// Whether the bound controller is a PlayStation controller
    var isPlayStation: Bool { isDualSense || isDualShock4 }

    /// Battery level if available
    var batteryLevel: Float? { controller?.battery?.batteryLevel }

    /// Battery state if available
    var batteryState: GCDeviceBattery.State? { controller?.battery?.batteryState }

    /// Set player index LED
    func setPlayerIndex(_ index: Int) {
        controller?.playerIndex = GCControllerPlayerIndex(rawValue: index) ?? .indexUnset
    }
}
