//
//  ChiakiApp.swift
//  Chiaki
//
//  PlayStation Remote Play client for Apple platforms
//

import SwiftUI

#if os(iOS) || os(macOS)
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

            // View Menu - Streaming Controls
            CommandMenu("View") {
                Button("Toggle Controls") {
                    navigationManager.toggleControlMenuTrigger.toggle()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(!navigationManager.isStreaming)

                Divider()

                Menu("Display Mode") {
                    ForEach(StreamSettings.DisplayMode.allCases) { mode in
                        Button(mode.rawValue) {
                            navigationManager.displayModeChangeTrigger = mode
                            settingsStore.updateDisplayMode(mode)
                        }
                        .keyboardShortcut(displayModeShortcut(for: mode), modifiers: .command)
                    }
                }
                .disabled(!navigationManager.isStreaming)

                Divider()

                Button("Volume Up") {
                    let newVolume = min(1.0, settingsStore.streamSettings.volume + 0.1)
                    navigationManager.volumeChangeTrigger = newVolume
                    settingsStore.updateVolume(newVolume)
                }
                .keyboardShortcut(.upArrow, modifiers: [.command])
                .disabled(!navigationManager.isStreaming)

                Button("Volume Down") {
                    let newVolume = max(0.0, settingsStore.streamSettings.volume - 0.1)
                    navigationManager.volumeChangeTrigger = newVolume
                    settingsStore.updateVolume(newVolume)
                }
                .keyboardShortcut(.downArrow, modifiers: [.command])
                .disabled(!navigationManager.isStreaming)

                Button("Mute") {
                    navigationManager.volumeChangeTrigger = 0.0
                    settingsStore.updateVolume(0.0)
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
                .disabled(!navigationManager.isStreaming)
            }

            SidebarCommands()
        }
        #endif
    }

    #if os(macOS)
    private func displayModeShortcut(for mode: StreamSettings.DisplayMode) -> KeyEquivalent {
        switch mode {
        case .normal: return "1"
        case .stretch: return "2"
        case .zoom: return "3"
        }
    }
    #endif
}
#endif
