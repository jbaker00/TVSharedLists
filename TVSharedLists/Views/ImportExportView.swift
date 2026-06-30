import SwiftUI
import UniformTypeIdentifiers

struct ImportExportView: View {
    @ObservedObject var viewModel: TVShowViewModel

    @State private var csvDocument: CSVDocument?
    @State private var isExportingToFile = false
    @State private var isImportingFromFile = false
    @State private var errorMessage: String?

    private var hasShows: Bool { !viewModel.shows.isEmpty }

    private var csvFileName: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "TVShows-\(f.string(from: Date())).csv"
    }

    var body: some View {
        NavigationStack {
            List {
                storageSection
                backupSection
                csvFormatSection
            }
            .navigationTitle("Settings")
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .fileExporter(
                isPresented: $isExportingToFile,
                document: csvDocument,
                contentType: .commaSeparatedText,
                defaultFilename: csvFileName
            ) { result in
                if case .failure(let error) = result { errorMessage = error.localizedDescription }
            }
            .fileImporter(
                isPresented: $isImportingFromFile,
                allowedContentTypes: [.commaSeparatedText, .plainText]
            ) { result in
                handleFileImportResult(result)
            }
        }
    }

    // MARK: - Storage / iCloud

    private var storageSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { !viewModel.localOnly },
                set: { viewModel.localOnly = !$0 }
            )) {
                Label("Sync with iCloud", systemImage: "icloud")
            }
            .tint(.indigo)

            if !viewModel.localOnly {
                if viewModel.iCloudAvailable {
                    HStack {
                        Image(systemName: viewModel.syncStatus.icon)
                            .foregroundStyle(viewModel.syncStatus.isError ? .red : .secondary)
                        Text(viewModel.syncStatus.label)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Sync Now") {
                            Task { await viewModel.manager.refreshIfNeeded() }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.indigo)
                    }
                } else {
                    Label("Sign in to iCloud under Settings to enable sync and sharing.",
                          systemImage: "exclamationmark.icloud")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("iCloud")
        } footer: {
            Text(viewModel.localOnly
                 ? "Your lists are stored only on this device. Enable iCloud Sync to sync across devices and share lists with others."
                 : "Your lists sync via iCloud. To share a list, create one from the My List tab and tap the share icon.")
        }
    }

    // MARK: - Backup (CSV only)

    private var backupSection: some View {
        Section {
            Button {
                csvDocument = CSVDocument(content: CSVService.exportCSV(shows: viewModel.allShows))
                isExportingToFile = true
            } label: {
                Label("Export All Shows to CSV…", systemImage: "square.and.arrow.down")
            }
            .disabled(!hasShows)

            Button {
                isImportingFromFile = true
            } label: {
                Label("Restore from CSV…", systemImage: "square.and.arrow.up")
            }

            if !hasShows {
                Text("Add some shows first to export a backup.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Backup (\(viewModel.allShows.count) shows across all lists)")
        } footer: {
            Text("Export saves all your shows across every list to a CSV file you can keep as a backup. Restore imports a CSV back into your current list.")
        }
    }

    // MARK: - CSV format

    private var csvFormatSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Column order:")
                    .font(.caption.weight(.semibold))
                Text(CSVService.headerRow)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                BulletText("Rating: 0–5 (0 = unrated)")
                BulletText("Thumbs: \"Loved It\", \"Not For Me\", or \"None\"")
                BulletText("Genres: separated by \"; \" (semicolon + space)")
                BulletText("Date format: YYYY-MM-DD")
                BulletText("Status: \"Watched\" or \"Want to Watch\"")
            }
        } header: {
            Text("CSV Format")
        }
    }

    // MARK: - Import handler

    private func handleFileImportResult(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Could not access the selected file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let content = try? String(contentsOf: url, encoding: .utf8) else {
                errorMessage = "Could not read the file. Make sure it is a plain-text CSV."
                return
            }
            do {
                let shows = try CSVService.importCSV(content)
                viewModel.pendingImportShows = shows
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Helpers

struct BulletText: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•").font(.caption).foregroundStyle(.secondary)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }
}
