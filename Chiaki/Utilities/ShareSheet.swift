// SPDX-License-Identifier: AGPL-3.0-only
//
// ShareSheet.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Reusable sharing components for iOS and macOS
// @requirement F-019 - 完善日志系统

import SwiftUI

#if os(iOS)
import UIKit

/// iOS Share Sheet (UIActivityViewController wrapper)
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#elseif os(macOS)
import AppKit

/// macOS Share Sheet equivalent
struct ShareSheet: View {
    @Environment(\.dismiss) var dismiss
    var activityItems: [Any]
    
    var body: some View {
        VStack(spacing: 16) {
            Text(L10n.Settings.Logs.diagnosticExportSuccess)
                .font(.headline)
            
            if let url = activityItems.first as? URL {
                Text(url.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button(L10n.Settings.Logs.showInFinder) {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                .buttonStyle(.borderedProminent)
            }
            
            Button(L10n.Common.done) {
                dismiss()
            }
        }
        .padding()
        .frame(width: 300)
    }
}
#endif
