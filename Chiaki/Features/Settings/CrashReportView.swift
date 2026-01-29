// SPDX-License-Identifier: AGPL-3.0-only
//
// CrashReportView.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// View for displaying and handling crash reports
// @requirement F-019 - 完善日志系统

import SwiftUI

/// View that displays a crash report to the user
/// @requirement F-019 - 完善日志系统
/// @satisfies AC-052 - 崩溃捕捉与报告
struct CrashReportView: View {
    @Environment(\.dismiss) private var dismiss
    let report: String
    
    @State private var showShareSheet = false
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.Settings.CrashReport.detected)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                
                ScrollView {
                    Text(report)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .background(Color.secondary.opacity(0.1))
                .clipShape(.rect(cornerRadius: 8))
                .padding(.horizontal)
                
                HStack(spacing: 12) {
                    Button(action: {
                        #if os(iOS)
                        UIPasteboard.general.string = report
                        #elseif os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(report, forType: .string)
                        #endif
                    }) {
                        Label(L10n.Settings.CrashReport.copyToClipboard, systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        showShareSheet = true
                    }) {
                        Label(L10n.Settings.CrashReport.share, systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                
                Button(role: .destructive) {
                    CrashReporter.shared.clearCrashReport()
                    dismiss()
                } label: {
                    Text(L10n.Settings.CrashReport.dismissAndClear)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .navigationTitle(L10n.Settings.CrashReport.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.done) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                #if os(iOS)
                ShareSheet(activityItems: [report])
                #elseif os(macOS)
                ShareSheet(activityItems: [writeReportToTempFile()])
                #endif
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 600)
        #endif
    }
    
    #if os(macOS)
    private func writeReportToTempFile() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("chiaki-crash-report.txt")
        try? report.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    #endif
}

#Preview {
    CrashReportView(report: "Sample crash report content")
}
