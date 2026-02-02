// SPDX-License-Identifier: AGPL-3.0-only
//
// ControllerShortcutDetector.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Detects controller button combinations for app shortcuts

import Foundation

/**
 * Detects controller button combinations for quick access to app features
 * @requirement F-020 - 手柄操作友好化
 * @satisfies AC-059 - 手柄组合键快捷操作
 */
final class ControllerShortcutDetector {

    // MARK: - Constants

    /// Debounce interval to prevent repeated triggering (200ms)
    static let debounceInterval: TimeInterval = 0.2

    // MARK: - Shortcut Definitions

    /// PS + Options combination for menu shortcut
    private static let menuShortcut: ChiakiControllerButtons = [.ps, .options]

    /// L1 + R1 + PS combination for disconnect shortcut
    private static let disconnectShortcut: ChiakiControllerButtons = [.l1, .r1, .ps]

    // MARK: - Callbacks

    /// Called when PS + Options is pressed (show/hide control menu)
    var onMenuShortcut: (() -> Void)?

    /// Called when L1 + R1 + PS is pressed (disconnect)
    var onDisconnectShortcut: (() -> Void)?

    // MARK: - State

    /// Previous button state for detecting newly pressed buttons
    private var previousButtons: ChiakiControllerButtons = []

    /// Whether menu shortcut was triggered for current button combination
    private var menuShortcutTriggeredForCurrentPress: Bool = false

    /// Whether disconnect shortcut was triggered for current button combination
    private var disconnectShortcutTriggeredForCurrentPress: Bool = false

    /// Timestamp of last menu shortcut trigger (for debounce across releases)
    private var lastMenuTriggerTime: Date = .distantPast

    /// Timestamp of last disconnect shortcut trigger (for debounce across releases)
    private var lastDisconnectTriggerTime: Date = .distantPast

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /**
     * Update the current button state and check for shortcuts
     * @param buttons Current pressed buttons
     * @satisfies AC-059 - 仅在新按键按下时检测
     */
    func updateButtons(_ buttons: ChiakiControllerButtons) {
        // Calculate newly pressed buttons (not previously held)
        let newlyPressed = buttons.subtracting(previousButtons)

        // Reset triggered flags when buttons are released
        if !buttons.containsAll(Self.menuShortcut) {
            menuShortcutTriggeredForCurrentPress = false
        }
        if !buttons.containsAll(Self.disconnectShortcut) {
            disconnectShortcutTriggeredForCurrentPress = false
        }

        // Only check shortcuts when new buttons are pressed
        if !newlyPressed.isEmpty {
            checkShortcuts(currentButtons: buttons)
        }

        // Update previous state
        previousButtons = buttons
    }

    /**
     * Reset the detector state
     */
    func reset() {
        previousButtons = []
        menuShortcutTriggeredForCurrentPress = false
        disconnectShortcutTriggeredForCurrentPress = false
        lastMenuTriggerTime = .distantPast
        lastDisconnectTriggerTime = .distantPast
    }

    // MARK: - Private Methods

    /**
     * Check if any shortcut combination is active
     * @param currentButtons Currently pressed buttons
     */
    private func checkShortcuts(currentButtons: ChiakiControllerButtons) {
        let now = Date()

        // Check disconnect shortcut first (more specific, 3 buttons)
        if currentButtons.containsAll(Self.disconnectShortcut) {
            // Only trigger if not already triggered for this press and past debounce
            if !disconnectShortcutTriggeredForCurrentPress &&
               now.timeIntervalSince(lastDisconnectTriggerTime) >= Self.debounceInterval {
                disconnectShortcutTriggeredForCurrentPress = true
                lastDisconnectTriggerTime = now
                triggerCallback(onDisconnectShortcut)
            }
            return // Don't check menu shortcut if disconnect combination is active
        }

        // Check menu shortcut (2 buttons)
        if currentButtons.containsAll(Self.menuShortcut) {
            // Only trigger if not already triggered for this press and past debounce
            if !menuShortcutTriggeredForCurrentPress &&
               now.timeIntervalSince(lastMenuTriggerTime) >= Self.debounceInterval {
                menuShortcutTriggeredForCurrentPress = true
                lastMenuTriggerTime = now
                triggerCallback(onMenuShortcut)
            }
        }
    }

    /**
     * Trigger callback on main thread
     * @param callback The callback to execute
     * @satisfies AC-059 - 回调在主线程执行
     */
    private func triggerCallback(_ callback: (() -> Void)?) {
        guard let callback = callback else { return }

        if Thread.isMainThread {
            callback()
        } else {
            DispatchQueue.main.async {
                callback()
            }
        }
    }
}

// MARK: - ChiakiControllerButtons Extension

extension ChiakiControllerButtons {
    /// Check if this button set contains all buttons in another set (is superset)
    func containsAll(_ other: ChiakiControllerButtons) -> Bool {
        return self.isSuperset(of: other)
    }
}
