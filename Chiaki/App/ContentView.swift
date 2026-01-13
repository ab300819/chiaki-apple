//
//  ContentView.swift
//  Chiaki
//
//  Main content view - placeholder for navigation structure
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            List {
                Text("Host List")
                    .font(.headline)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        } detail: {
            VStack {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text("Chiaki")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("PlayStation Remote Play")
                    .foregroundStyle(.secondary)
            }
        }
        #else
        NavigationStack {
            List {
                Text("Host List")
                    .font(.headline)
            }
            .navigationTitle("Chiaki")
        }
        #endif
    }
}

#Preview {
    ContentView()
}
