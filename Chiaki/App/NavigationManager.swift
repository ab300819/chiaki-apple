//
//  NavigationManager.swift
//  Chiaki
//
//  Created for Chiaki native macOS support.
//

import SwiftUI
import Observation
import Combine

enum SidebarItem: Hashable {
    case hosts
    case settings
}

@Observable class NavigationManager {
    // Sidebar Navigation
    var sidebarSelection: SidebarItem? = .hosts

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
        sidebarSelection = .hosts
        // Trigger the sheet
        showAddHostSheet = true
    }
    
    func navigateToSettings() {
        sidebarSelection = .settings
    }
    
    func refreshDiscovery() {
        sidebarSelection = .hosts
        refreshDiscoveryTrigger = true
        // Reset trigger after a short delay or let the view handle it
        // Ideally, the view watches this value or we use a PassthroughSubject
        // For simplicity with @Published, we can toggle it
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
