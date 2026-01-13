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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settingsStore)
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 720)
        #endif
    }
}
