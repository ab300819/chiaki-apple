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
                    NavigationLink(destination: GeneralSettingsView()) {
                        Label(L10n.Nav.general, systemImage: "gearshape")
                    }
                    NavigationLink(destination: VideoSettingsView()) {
                        Label(L10n.Nav.video, systemImage: "display")
                    }
                    NavigationLink(destination: AudioSettingsView()) {
                        Label(L10n.Nav.audio, systemImage: "speaker.wave.2")
                    }
                    NavigationLink(destination: ControllerSettingsView()) {
                        Label(L10n.Nav.controller, systemImage: "gamecontroller")
                    }
                }

                Section {
                    NavigationLink(destination: AccountSettingsView()) {
                        Label(L10n.Nav.account, systemImage: "person.crop.circle")
                    }
                    NavigationLink(destination: ConsolesSettingsView()) {
                        Label(L10n.Nav.consoles, systemImage: "server.rack")
                    }
                }

                Section {
                    NavigationLink(destination: LogViewerView()) {
                        Label(L10n.Nav.logs, systemImage: "doc.text")
                    }
                }

                Section(L10n.Nav.data) {
                    Button {
                        exportSettings()
                    } label: {
                        Label(L10n.Settings.Data.exportSettings, systemImage: "square.and.arrow.up")
                    }

                    Button {
                        isImporting = true
                    } label: {
                        Label(L10n.Settings.Data.importSettings, systemImage: "square.and.arrow.down")
                    }

                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Label(L10n.Settings.Data.resetToDefaults, systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle(L10n.Nav.settings)
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
                L10n.Settings.Data.resetTitle,
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button(L10n.Settings.Data.resetToDefaults, role: .destructive) {
                    store.resetToDefaults()
                }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Settings.Data.resetMessage)
            }
            .alert(String(localized: "settings.data.importFailed"), isPresented: $showImportError) {
                Button(L10n.Common.ok, role: .cancel) {}
            } message: {
                Text(importErrorMessage)
            }
        }
        #elseif os(macOS)
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label(L10n.Nav.general, systemImage: "gearshape")
                }

            VideoSettingsView()
                .tabItem {
                    Label(L10n.Nav.video, systemImage: "display")
                }

            AudioSettingsView()
                .tabItem {
                    Label(L10n.Nav.audio, systemImage: "speaker.wave.2")
                }

            ControllerSettingsView()
                .tabItem {
                    Label(L10n.Nav.controller, systemImage: "gamecontroller")
                }

            AccountSettingsView()
                .tabItem {
                    Label(L10n.Nav.account, systemImage: "person.crop.circle")
                }

            ConsolesSettingsView()
                .tabItem {
                    Label(L10n.Nav.consoles, systemImage: "server.rack")
                }

            LogViewerView()
                .tabItem {
                    Label(L10n.Nav.logs, systemImage: "doc.text")
                }

            DataSettingsView(store: store)
                .tabItem {
                    Label(L10n.Nav.data, systemImage: "externaldrive")
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
            importErrorMessage = L10n.Error.exportFailed(error.localizedDescription)
            showImportError = true
        }
    }

    func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                importErrorMessage = L10n.Error.unableToAccessFile
                showImportError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                try store.importSettings(from: data)
            } catch {
                importErrorMessage = L10n.Error.importFailed(error.localizedDescription)
                showImportError = true
            }
        case .failure(let error):
            importErrorMessage = error.localizedDescription
            showImportError = true
        }
    }
}

// MARK: - Settings Category (macOS)

#if os(macOS)
/**
 * Settings navigation categories for macOS sidebar
 * @requirement F-034
 * @satisfies AC-122 - 左侧列表显示所有设置分类
 * @satisfies AC-125 - 设置分类保持与现有顺序一致
 */
enum SettingsCategory: String, CaseIterable, Identifiable, Hashable {
    case general
    case video
    case audio
    case controller
    case account
    case consoles
    case logs
    case data

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: L10n.Nav.general
        case .video: L10n.Nav.video
        case .audio: L10n.Nav.audio
        case .controller: L10n.Nav.controller
        case .account: L10n.Nav.account
        case .consoles: L10n.Nav.consoles
        case .logs: L10n.Nav.logs
        case .data: L10n.Nav.data
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .video: "display"
        case .audio: "speaker.wave.2"
        case .controller: "gamecontroller"
        case .account: "person.crop.circle"
        case .consoles: "server.rack"
        case .logs: "doc.text"
        case .data: "externaldrive"
        }
    }
}
#endif

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
                Button(L10n.Settings.Data.exportSettings) {
                    exportSettings()
                }

                Button(L10n.Settings.Data.importSettings) {
                    isImporting = true
                }
            }

            Section {
                Button(L10n.Settings.Data.resetToDefaults, role: .destructive) {
                    showResetConfirmation = true
                }
                .foregroundStyle(.red)
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
            L10n.Settings.Data.resetTitle,
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.Settings.Data.resetToDefaults, role: .destructive) {
                store.resetToDefaults()
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(String(localized: "settings.data.resetMessageShort"))
        }
        .alert(String(localized: "settings.data.importFailed"), isPresented: $showImportError) {
            Button(L10n.Common.ok, role: .cancel) {}
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
            importErrorMessage = L10n.Error.exportFailed(error.localizedDescription)
            showImportError = true
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                importErrorMessage = L10n.Error.unableToAccessFile
                showImportError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                try store.importSettings(from: data)
            } catch {
                importErrorMessage = L10n.Error.importFailed(error.localizedDescription)
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
