//
//  NavigationManager.swift
//  Chiaki
//
//  Created for Chiaki native macOS support.
//

import SwiftUI
import Combine

class NavigationManager: ObservableObject {
    // Sidebar Navigation
    @Published var sidebarSelection: SidebarItem? = .hosts
    
    // Command Triggers
    @Published var showAddHostSheet: Bool = false
    @Published var refreshDiscoveryTrigger: Bool = false
    @Published var wakeUpSelectedHostTrigger: Bool = false
    
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
}
