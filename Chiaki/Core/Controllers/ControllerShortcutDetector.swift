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
 * @requirement F-022 - 手柄操控 UI/UX 优化
 * @satisfies AC-059 - 手柄组合键快捷操作
 * @satisfies AC-066 - 流媒体中音量快捷调节
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

    /// PS + R2 combination for volume up
    /// @satisfies AC-066 - PS+R2 音量+
    private static let volumeUpShortcut: ChiakiControllerButtons = [.ps, .r2]

    /// PS + L2 combination for volume down
    /// @satisfies AC-066 - PS+L2 音量-
    private static let volumeDownShortcut: ChiakiControllerButtons = [.ps, .l2]

    // MARK: - Callbacks

    /// Called when PS + Options is pressed (show/hide control menu)
    var onMenuShortcut: (() -> Void)?

    /// Called when L1 + R1 + PS is pressed (disconnect)
    var onDisconnectShortcut: (() -> Void)?

    /// Called when PS + R2 is pressed (volume up)
    /// @satisfies AC-066 - 音量+回调
    var onVolumeUp: (() -> Void)?

    /// Called when PS + L2 is pressed (volume down)
    /// @satisfies AC-066 - 音量-回调
    var onVolumeDown: (() -> Void)?

    // MARK: - State

    /// Previous button state for detecting newly pressed buttons
    private var previousButtons: ChiakiControllerButtons = []

    /// Whether menu shortcut was triggered for current button combination
    private var menuShortcutTriggeredForCurrentPress: Bool = false

    /// Whether disconnect shortcut was triggered for current button combination
    private var disconnectShortcutTriggeredForCurrentPress: Bool = false

    /// Whether volume up shortcut was triggered for current button combination
    private var volumeUpTriggeredForCurrentPress: Bool = false

    /// Whether volume down shortcut was triggered for current button combination
    private var volumeDownTriggeredForCurrentPress: Bool = false

    /// Timestamp of last menu shortcut trigger (for debounce across releases)
    private var lastMenuTriggerTime: Date = .distantPast

    /// Timestamp of last disconnect shortcut trigger (for debounce across releases)
    private var lastDisconnectTriggerTime: Date = .distantPast

    /// Timestamp of last volume up trigger (for debounce)
    /// @satisfies AC-066 - 200ms 节流
    private var lastVolumeUpTriggerTime: Date = .distantPast

    /// Timestamp of last volume down trigger (for debounce)
    /// @satisfies AC-066 - 200ms 节流
    private var lastVolumeDownTriggerTime: Date = .distantPast

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
        if !buttons.containsAll(Self.volumeUpShortcut) {
            volumeUpTriggeredForCurrentPress = false
        }
        if !buttons.containsAll(Self.volumeDownShortcut) {
            volumeDownTriggeredForCurrentPress = false
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
        volumeUpTriggeredForCurrentPress = false
        volumeDownTriggeredForCurrentPress = false
        lastMenuTriggerTime = .distantPast
        lastDisconnectTriggerTime = .distantPast
        lastVolumeUpTriggerTime = .distantPast
        lastVolumeDownTriggerTime = .distantPast
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
            return // Don't check volume shortcuts if menu combination is active
        }

        // Check volume shortcuts
        // AC-066: Conflict protection - if both L2 and R2 are pressed with PS, ignore
        let hasL2 = currentButtons.contains(.l2)
        let hasR2 = currentButtons.contains(.r2)
        let hasPS = currentButtons.contains(.ps)

        if hasPS && hasL2 && hasR2 {
            // Both triggers pressed - conflict, do nothing
            return
        }

        // Check volume up (PS + R2)
        if currentButtons.containsAll(Self.volumeUpShortcut) {
            if !volumeUpTriggeredForCurrentPress &&
               now.timeIntervalSince(lastVolumeUpTriggerTime) >= Self.debounceInterval {
                volumeUpTriggeredForCurrentPress = true
                lastVolumeUpTriggerTime = now
                triggerCallback(onVolumeUp)
            }
            return
        }

        // Check volume down (PS + L2)
        if currentButtons.containsAll(Self.volumeDownShortcut) {
            if !volumeDownTriggeredForCurrentPress &&
               now.timeIntervalSince(lastVolumeDownTriggerTime) >= Self.debounceInterval {
                volumeDownTriggeredForCurrentPress = true
                lastVolumeDownTriggerTime = now
                triggerCallback(onVolumeDown)
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
