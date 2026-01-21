// SPDX-License-Identifier: AGPL-3.0-only
//
// LogViewerView.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// In-app log viewer for diagnostics and troubleshooting

import SwiftUI
import UniformTypeIdentifiers

struct LogViewerView: View {
    @State private var searchText = ""
    @State private var selectedLevel: ChiakiLogSeverity?
    @State private var isExporting = false
    @State private var exportDocument: LogDocument?

    private var filteredLogs: [Logger.LogEntry] {
        Logger.shared.logHistory.filter { entry in
            let matchesSearch = searchText.isEmpty || entry.message.localizedCaseInsensitiveContains(searchText)
            let matchesLevel = selectedLevel == nil || entry.level == selectedLevel
            return matchesSearch && matchesLevel
        }.reversed()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filters
            HStack {
                Picker("Level", selection: $selectedLevel) {
                    Text(L10n.Settings.Logs.allLevels).tag(nil as ChiakiLogSeverity?)
                    Divider()
                    ForEach(ChiakiLogSeverity.allCases, id: \.self) { level in
                        Text(level.description).tag(level as ChiakiLogSeverity?)
                    }
                }
                .pickerStyle(.menu)

                Spacer()

                Button(action: {
                    exportLogs()
                }) {
                    Label(L10n.Settings.Logs.export, systemImage: "square.and.arrow.up")
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))

            // Log List
            List(filteredLogs) { entry in
                LogEntryRow(entry: entry)
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "Search logs")
        }
        .navigationTitle(L10n.Settings.Logs.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .plainText,
            defaultFilename: "chiaki-logs-\(Date().ISO8601Format())"
        ) { result in
            if case .failure(let error) = result {
                Logger.storage.error("Failed to export logs: \(error.localizedDescription)")
            }
        }
    }

    private func exportLogs() {
        let logsText = formatLogsForExport()
        exportDocument = LogDocument(text: logsText)
        isExporting = true
    }

    private func formatLogsForExport() -> String {
        var lines: [String] = []
        lines.append("Chiaki Logs Export")
        lines.append("Generated: \(Date().formatted())")
        lines.append("Total entries: \(filteredLogs.count)")
        lines.append(String(repeating: "-", count: 80))
        lines.append("")

        for entry in filteredLogs.reversed() {
            let timestamp = entry.timestamp.formatted(date: .abbreviated, time: .standard)
            let level = entry.level.description.uppercased().padding(toLength: 7, withPad: " ", startingAt: 0)
            let category = "[\(entry.category)]".padding(toLength: 15, withPad: " ", startingAt: 0)
            lines.append("\(timestamp) \(level) \(category) \(entry.message)")
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Log Document for File Export

struct LogDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(decoding: data, as: UTF8.self)
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}

private struct LogEntryRow: View {
    let entry: Logger.LogEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.level.description.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(levelColor.opacity(0.2))
                    .foregroundColor(levelColor)
                    .cornerRadius(4)
                
                Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(entry.category)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Text(entry.message)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }
    
    private var levelColor: Color {
        switch entry.level {
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        case .debug: return .gray
        case .verbose: return .secondary
        }
    }
}

extension ChiakiLogSeverity: CaseIterable {
    public static var allCases: [ChiakiLogSeverity] {
        [.error, .warning, .info, .debug, .verbose]
    }
    
    var description: String {
        switch self {
        case .error: return "Error"
        case .warning: return "Warning"
        case .info: return "Info"
        case .debug: return "Debug"
        case .verbose: return "Verbose"
        }
    }
}

#Preview {
    NavigationStack {
        LogViewerView()
    }
}
