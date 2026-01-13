//
//  ChiakiTVApp.swift
//  ChiakiTV
//
//  PlayStation Remote Play client for tvOS
//

import SwiftUI

@main
struct ChiakiTVApp: App {
    var body: some Scene {
        WindowGroup {
            TVContentView()
        }
    }
}

struct TVContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Text("Host List")
                    .font(.headline)
            }
            .navigationTitle("Chiaki")
        }
    }
}

#Preview {
    TVContentView()
}
