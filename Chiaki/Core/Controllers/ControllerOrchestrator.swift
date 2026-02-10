// SPDX-License-Identifier: AGPL-3.0-only
//
// ControllerOrchestrator.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Central coordinator for controller input providers.
// Routes input from multiple sources (GC framework, IOKit HID) and
// dispatches feedback to the most capable output provider.

import Foundation
import GameController
import SwiftUI

/// Orchestrates multiple controller input providers and unifies their output.
///
/// Design:
/// - GameControllerProvider handles standard input (buttons, sticks, triggers, touchpad, motion)
/// - DualSenseHIDProvider (macOS) handles PS button + HID rumble/LED
/// - Input from HID providers is merged into the GC provider's state
/// - Feedback is routed to the most capable output (HID preferred over GC)
///
/// @requirement F-040 - 控制器架構分層重構
/// @satisfies AC-152 - HID 優先 GC fallback
/// @satisfies AC-154 - FeedbackOutput 統一路由
/// @satisfies AC-155 - Orchestrator < 300 行
@MainActor
@Observable
final class ControllerOrchestrator {

    // MARK: - Published State

    /// All connected controllers (for UI display)
    private(set) var connectedControllers: [ControllerInfo] = []

    /// Currently active controller info
    private(set) var activeController: ControllerInfo?

    /// Current merged controller input state
    private(set) var currentInput = ChiakiControllerInput()

    /// Whether haptic feedback is enabled
    var hapticsEnabled: Bool = true

    /// Whether adaptive triggers are enabled
    var adaptiveTriggersEnabled: Bool = true

    // MARK: - Callbacks

    /// Called when merged controller input changes
    var onInputChanged: ((ChiakiControllerInput) -> Void)?

    // MARK: - Providers

    /// GCController-based provider for the active controller
    private let gcProvider = GameControllerProvider(providerId: "gc-primary")

    #if os(macOS)
    /// Direct HID provider for DualSense PS button + rumble (macOS only)
    private let hidProvider = DualSenseHIDProvider.shared
    #endif

    /// The preferred feedback output (HID > GC)
    private var feedbackProvider: ControllerFeedbackOutput? {
        #if os(macOS)
        if hidProvider.isConnected { return hidProvider }
        #endif
        if gcProvider.isConnected { return gcProvider }
        return nil
    }

    /// Adaptive trigger state
    private(set) var adaptiveTriggerState = AdaptiveTriggerState()

    // MARK: - Private

    private var notificationObservers: [NSObjectProtocol] = []

    // MARK: - Singleton

    static let shared = ControllerOrchestrator()

    /// Preview instance without GCController framework
    static let preview: ControllerOrchestrator = {
        ControllerOrchestrator(forPreview: true)
    }()

    // MARK: - Initialization

    private init(forPreview: Bool = false) {
        guard !forPreview else {
            Logger.controller.debug("ControllerOrchestrator initialized for preview")
            return
        }
        setupGCProvider()
        setupNotifications()
        scanConnectedControllers()
        #if os(macOS)
        setupHIDProvider()
        #endif
        Logger.controller.info("ControllerOrchestrator initialized")
    }

    // MARK: - GC Provider Setup

    private func setupGCProvider() {
        gcProvider.onInputChanged = { [weak self] input in
            self?.handleGCInput(input)
        }
        gcProvider.onConnectionChanged = { [weak self] connected in
            Logger.controller.debug("GC provider connection: \(connected)")
            // Connection state managed by GCController notifications
        }
    }

    #if os(macOS)
    private func setupHIDProvider() {
        hidProvider.start()
        hidProvider.onInputChanged = { [weak self] hidInput in
            self?.handleHIDInput(hidInput)
        }
        Logger.controller.info("DualSense HID provider configured")
    }
    #endif

    // MARK: - GCController Notifications

    private func setupNotifications() {
        let connectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect, object: nil, queue: .main
        ) { [weak self] notification in
            guard let self, let controller = notification.object as? GCController else { return }
            Task { @MainActor in self.handleControllerConnected(controller) }
        }
        notificationObservers.append(connectObserver)

        let disconnectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect, object: nil, queue: .main
        ) { [weak self] notification in
            guard let self, let controller = notification.object as? GCController else { return }
            Task { @MainActor in self.handleControllerDisconnected(controller) }
        }
        notificationObservers.append(disconnectObserver)

        let becomeCurrentObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidBecomeCurrent, object: nil, queue: .main
        ) { [weak self] notification in
            guard let self, let controller = notification.object as? GCController else { return }
            Task { @MainActor in self.setActiveController(controller) }
        }
        notificationObservers.append(becomeCurrentObserver)
    }

    private func scanConnectedControllers() {
        for controller in GCController.controllers() {
            handleControllerConnected(controller)
        }
        if let ps = connectedControllers.first(where: { $0.isPlayStationController }) {
            setActiveController(ps.controller)
        } else if let first = connectedControllers.first {
            setActiveController(first.controller)
        }
    }

    // MARK: - Controller Connection

    private func handleControllerConnected(_ controller: GCController) {
        guard !connectedControllers.contains(where: { $0.controller === controller }) else { return }
        let info = ControllerInfo(controller: controller)
        connectedControllers.append(info)
        Logger.controller.info("Controller connected: \(info.name) (\(info.productCategory))")

        if activeController == nil {
            setActiveController(controller)
        }
    }

    private func handleControllerDisconnected(_ controller: GCController) {
        guard let index = connectedControllers.firstIndex(where: { $0.controller === controller }) else { return }
        connectedControllers.remove(at: index)
        Logger.controller.info("Controller disconnected")

        if activeController?.controller === controller {
            gcProvider.unbind()
            activeController = nil
            if let next = connectedControllers.first {
                setActiveController(next.controller)
            }
        }
    }

    private func setActiveController(_ controller: GCController) {
        for i in 0..<connectedControllers.count {
            connectedControllers[i].isActive = (connectedControllers[i].controller === controller)
        }
        activeController = connectedControllers.first(where: { $0.controller === controller })

        // Bind GC provider to the new active controller
        gcProvider.unbind()
        gcProvider.bind(to: controller)

        if let active = activeController {
            Logger.controller.info("Active controller: \(active.name)")
            if active.isDualSense {
                HapticsManager.shared.startEngine()
            }
        }
    }

    // MARK: - Input Merging

    /// Handle input from GCController provider — this is the main input path
    private func handleGCInput(_ input: ChiakiControllerInput) {
        var merged = input

        // Merge PS button from HID provider if available (HID is more reliable on macOS)
        #if os(macOS)
        if hidProvider.isConnected && hidProvider.currentInput.buttons.contains(.ps) {
            merged.buttons.insert(.ps)
        }
        #endif

        currentInput = merged
        onInputChanged?(merged)
    }

    /// Handle input from HID provider — only PS button state
    private func handleHIDInput(_ hidInput: ChiakiControllerInput) {
        // Merge HID PS button into current GC input
        var merged = gcProvider.currentInput
        if hidInput.buttons.contains(.ps) {
            merged.buttons.insert(.ps)
        } else {
            merged.buttons.remove(.ps)
        }

        currentInput = merged
        onInputChanged?(merged)
    }

    // MARK: - Feedback Output

    /// Apply rumble feedback, routing to the best available provider.
    /// On macOS: HID provider preferred (GCDeviceHaptics is unreliable).
    /// On iOS/tvOS: GC provider (only option).
    func applyRumble(left: UInt8, right: UInt8) {
        guard hapticsEnabled, left > 0 || right > 0 else { return }

        #if os(macOS)
        if hidProvider.isConnected {
            hidProvider.sendRumble(left: left, right: right)
            return
        }
        #endif

        if gcProvider.isConnected {
            gcProvider.sendRumble(left: left, right: right)
        } else {
            HapticsManager.shared.applyRumble(left: left, right: right)
        }
    }

    /// Apply adaptive trigger effect.
    func applyAdaptiveTrigger(effect: AdaptiveTriggerEffect, side: TriggerSide) {
        guard adaptiveTriggersEnabled else { return }
        gcProvider.applyAdaptiveTrigger(effect: effect, side: side)

        switch side {
        case .left: adaptiveTriggerState.leftEffect = effect
        case .right: adaptiveTriggerState.rightEffect = effect
        }
    }

    /// Reset both adaptive triggers.
    func resetAdaptiveTriggers() {
        gcProvider.applyAdaptiveTrigger(effect: .off, side: .left)
        gcProvider.applyAdaptiveTrigger(effect: .off, side: .right)
        adaptiveTriggerState.reset()
    }

    /// Set LED color on the active controller.
    func setLEDColor(r: UInt8, g: UInt8, b: UInt8) {
        #if os(macOS)
        if hidProvider.isConnected {
            hidProvider.setLEDColor(red: r, green: g, blue: b)
            return
        }
        #endif
        gcProvider.setLEDColor(red: r, green: g, blue: b)
    }

    /// Set player index LED.
    func setPlayerIndex(_ index: Int) {
        gcProvider.setPlayerIndex(index)
    }

    // MARK: - Motion

    func enableMotion() { gcProvider.enableMotion() }
    func disableMotion() { gcProvider.disableMotion() }

    // MARK: - Haptics (delegate to shared HapticsManager)

    func startHaptics() { HapticsManager.shared.startEngine() }
    func stopHaptics() { HapticsManager.shared.stopEngine() }

    // MARK: - Statistics (backward-compatible with ControllerManager API)

    var controllerCount: Int { connectedControllers.count }
    var hasPlayStationController: Bool { connectedControllers.contains(where: { $0.isPlayStationController }) }
    var hasDualSense: Bool { connectedControllers.contains(where: { $0.isDualSense }) }

    var detectedControllerType: ControllerHintType {
        guard let active = activeController else { return .generic }
        if active.isPlayStationController { return .playstation }
        let category = active.productCategory.lowercased()
        if category.contains("xbox") || category.contains("microsoft") { return .xbox }
        return .generic
    }

    enum ControllerHintType {
        case playstation
        case xbox
        case generic
    }

    var batteryInfo: BatteryInfo? {
        guard let controller = activeController?.controller,
              let battery = controller.battery else { return nil }
        return BatteryInfo(level: battery.batteryLevel,
                          state: BatteryInfo.BatteryState(from: battery.batteryState))
    }

    /// Battery information (mirrors ControllerManager.BatteryInfo for backward compat)
    struct BatteryInfo: Sendable, Equatable {
        let level: Float
        let state: BatteryState

        enum BatteryState: Int, Sendable {
            case unknown = -1
            case discharging = 0
            case charging = 1
            case full = 2

            init(from gcState: GCDeviceBattery.State) {
                switch gcState {
                case .unknown: self = .unknown
                case .discharging: self = .discharging
                case .charging: self = .charging
                case .full: self = .full
                @unknown default: self = .unknown
                }
            }
        }

        var isLow: Bool { level < 0.2 }

        var iconName: String {
            if state == .charging { return "battery.100.bolt" }
            if state == .full { return "battery.100" }
            if level >= 0.75 { return "battery.100" }
            if level >= 0.5 { return "battery.75" }
            if level >= 0.25 { return "battery.50" }
            return "battery.25"
        }

        var color: SwiftUI.Color {
            if state == .charging || state == .full { return .green }
            if isLow { return .red }
            return .primary
        }

        var percentageString: String { "\(Int(level * 100))%" }
    }
}
