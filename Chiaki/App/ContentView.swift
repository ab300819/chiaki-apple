//
//  ContentView.swift
//  Chiaki
//
//  Main content view with navigation structure
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            HostListView()
                .navigationSplitViewColumnWidth(min: 280, ideal: 320)
        } detail: {
            WelcomeView()
        }
        #else
        NavigationStack {
            HostListView()
        }
        #endif
    }
}

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("Chiaki")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("PlayStation Remote Play")
                .foregroundStyle(.secondary)
            Text("Select a host to start streaming")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    ContentView()
}
