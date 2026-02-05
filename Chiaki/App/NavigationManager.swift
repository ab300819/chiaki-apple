//
//  NavigationManager.swift
//  Chiaki
//
//  Created for Chiaki native macOS support.
//

import SwiftUI
import Observation
import Combine

/// App navigation tabs
/// [requirement] F-033
enum AppTab: Hashable {
    case hosts
    case settings
}

@Observable class NavigationManager {
    // Tab Navigation
    /// Current selected tab
    /// [satisfies] AC-117
    var selectedTab: AppTab = .hosts

    // Command Triggers
    var showAddHostSheet: Bool = false
    var refreshDiscoveryTrigger: Bool = false
    var wakeUpSelectedHostTrigger: Bool = false

    // Streaming State (for macOS menu integration)
    var isStreaming: Bool = false
    var toggleControlMenuTrigger: Bool = false
    var displayModeChangeTrigger: StreamSettings.DisplayMode?
    var volumeChangeTrigger: Double?

    // Auto-Connect State
    var isAutoConnecting: Bool = false
    var autoConnectHost: ConsoleHost?
    
    // Actions
    func openAddHost() {
        // Ensure we are on the hosts view
        selectedTab = .hosts
        // Trigger the sheet
        showAddHostSheet = true
    }
    
    func navigateToSettings() {
        selectedTab = .settings
    }
    
    func refreshDiscovery() {
        selectedTab = .hosts
        refreshDiscoveryTrigger = true
    }
    
    func wakeUpSelectedHost() {
        wakeUpSelectedHostTrigger = true
    }

    // MARK: - Auto-Connect

    /// Start auto-connect process for a specific host
    func startAutoConnect(host: ConsoleHost) {
        autoConnectHost = host
        isAutoConnecting = true
    }

    /// Cancel or complete auto-connect process
    func endAutoConnect() {
        isAutoConnecting = false
        autoConnectHost = nil
    }
}
