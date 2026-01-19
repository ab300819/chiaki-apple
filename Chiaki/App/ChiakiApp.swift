//
//  ChiakiApp.swift
//  Chiaki
//
//  PlayStation Remote Play client for Apple platforms
//

import SwiftUI

@main
struct ChiakiApp: App {
    @State private var settingsStore = SettingsStore()
    @State private var navigationManager = NavigationManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settingsStore)
                .environment(navigationManager)
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Host...") {
                    navigationManager.openAddHost()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandGroup(after: .newItem) {
                Button("Refresh Discovery") {
                    navigationManager.refreshDiscovery()
                }
                .keyboardShortcut("r", modifiers: .command)
                
                Button("Wake Up Selected Host") {
                    navigationManager.wakeUpSelectedHost()
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
            }
            
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    navigationManager.navigateToSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            
            SidebarCommands()
        }
        #endif
    }
}
