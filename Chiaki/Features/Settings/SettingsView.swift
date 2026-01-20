import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(SettingsStore.self) var store
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var showResetConfirmation = false
    @State private var exportDocument: SettingsDocument?
    @State private var showImportError = false
    @State private var importErrorMessage = ""

    var body: some View {
        #if os(iOS) || os(tvOS)
        NavigationStack {
            Form {
                Section {
                    NavigationLink(destination: VideoSettingsView()) {
                        Label("Video", systemImage: "display")
                    }
                    NavigationLink(destination: AudioSettingsView()) {
                        Label("Audio", systemImage: "speaker.wave.2")
                    }
                    NavigationLink(destination: ControllerSettingsView()) {
                        Label("Controller", systemImage: "gamecontroller")
                    }
                }
                
                Section {
                    NavigationLink(destination: AccountSettingsView()) {
                        Label("Account", systemImage: "person.crop.circle")
                    }
                }

                Section("Diagnostics") {
                    NavigationLink(destination: LogViewerView()) {
                        Label("Logs", systemImage: "doc.text")
                    }
                }

                Section("Data") {
                    Button {
                        exportSettings()
                    } label: {
                        Label("Export Settings", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        isImporting = true
                    } label: {
                        Label("Import Settings", systemImage: "square.and.arrow.down")
                    }

                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("Settings")
            .fileExporter(
                isPresented: $isExporting,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "chiaki-settings"
            ) { _ in }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.json]
            ) { result in
                handleImport(result)
            }
            .confirmationDialog(
                "Reset Settings",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset to Defaults", role: .destructive) {
                    store.resetToDefaults()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will reset all settings to their default values. This cannot be undone.")
            }
            .alert("Import Failed", isPresented: $showImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importErrorMessage)
            }
        }
        #elseif os(macOS)
        TabView {
            VideoSettingsView()
                .tabItem {
                    Label("Video", systemImage: "display")
                }
            
            AudioSettingsView()
                .tabItem {
                    Label("Audio", systemImage: "speaker.wave.2")
                }
            
            ControllerSettingsView()
                .tabItem {
                    Label("Controller", systemImage: "gamecontroller")
                }
            
            AccountSettingsView()
                .tabItem {
                    Label("Account", systemImage: "person.crop.circle")
                }

            LogViewerView()
                .tabItem {
                    Label("Logs", systemImage: "doc.text")
                }

            DataSettingsView(store: store)
                .tabItem {
                    Label("Data", systemImage: "externaldrive")
                }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
        #endif
    }
}

// MARK: - Private Methods

private extension SettingsView {
    func exportSettings() {
        do {
            let data = try store.exportSettings()
            exportDocument = SettingsDocument(data: data)
            isExporting = true
        } catch {
            importErrorMessage = "Failed to export: \(error.localizedDescription)"
            showImportError = true
        }
    }

    func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                importErrorMessage = "Unable to access the selected file"
                showImportError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                try store.importSettings(from: data)
            } catch {
                importErrorMessage = "Failed to import: \(error.localizedDescription)"
                showImportError = true
            }
        case .failure(let error):
            importErrorMessage = error.localizedDescription
            showImportError = true
        }
    }
}

// MARK: - Data Settings View (macOS)

#if os(macOS)
private struct DataSettingsView: View {
    let store: SettingsStore
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var showResetConfirmation = false
    @State private var exportDocument: SettingsDocument?
    @State private var showImportError = false
    @State private var importErrorMessage = ""

    var body: some View {
        Form {
            Section {
                Button("Export Settings...") {
                    exportSettings()
                }

                Button("Import Settings...") {
                    isImporting = true
                }
            }

            Section {
                Button("Reset to Defaults", role: .destructive) {
                    showResetConfirmation = true
                }
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "chiaki-settings"
        ) { _ in }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json]
        ) { result in
            handleImport(result)
        }
        .confirmationDialog(
            "Reset Settings",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset to Defaults", role: .destructive) {
                store.resetToDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset all settings to their default values.")
        }
        .alert("Import Failed", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage)
        }
    }

    private func exportSettings() {
        do {
            let data = try store.exportSettings()
            exportDocument = SettingsDocument(data: data)
            isExporting = true
        } catch {
            importErrorMessage = "Failed to export: \(error.localizedDescription)"
            showImportError = true
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                importErrorMessage = "Unable to access the selected file"
                showImportError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                try store.importSettings(from: data)
            } catch {
                importErrorMessage = "Failed to import: \(error.localizedDescription)"
                showImportError = true
            }
        case .failure(let error):
            importErrorMessage = error.localizedDescription
            showImportError = true
        }
    }
}
#endif

// MARK: - Settings Document

struct SettingsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    SettingsView()
        .environment(SettingsStore())
        .environment(NavigationManager())
}
