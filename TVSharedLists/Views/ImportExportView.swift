import SwiftUI
import UniformTypeIdentifiers

struct ImportExportView: View {
    @ObservedObject var viewModel: TVShowViewModel

    // Export state
    @State private var csvDocument: CSVDocument?
    @State private var isExportingToFile = false
    @State private var shareItems: [Any] = []
    @State private var isSharing = false

    // Import state
    @State private var isImportingFromFile = false
    @State private var pendingShows: [TVShow]?
    @State private var showMergeDialog = false

    // Feedback
    @State private var successMessage: String?
    @State private var errorMessage: String?

    private var hasShows: Bool { !viewModel.shows.isEmpty }
    private var exportFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "TVShows-\(formatter.string(from: Date())).csv"
    }

    var body: some View {
        NavigationStack {
            List {
                exportSection
                importSection
                csvFormatSection
            }
            .navigationTitle("Import / Export")
            .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .alert(
                "Import \(pendingShows?.count ?? 0) Shows",
                isPresented: $showMergeDialog,
                presenting: pendingShows
            ) { shows in
                Button("Replace All (delete existing list)") {
                    viewModel.replaceAllShows(with: shows)
                    viewModel.fetchMissingPosters()
                    successMessage = "Imported \(shows.count) shows. Your previous list was replaced."
                }
                Button("Merge (skip duplicates)") {
                    viewModel.appendShows(shows)
                    viewModel.fetchMissingPosters()
                    successMessage = "Merged \(shows.count) shows into your existing list."
                }
                Button("Cancel", role: .cancel) { pendingShows = nil }
            } message: { shows in
                Text("Found \(shows.count) valid shows.\n\nReplace your existing list or merge them together?")
            }
            .alert("Success", isPresented: Binding(get: { successMessage != nil }, set: { if !$0 { successMessage = nil } })) {
                Button("OK") { successMessage = nil }
            } message: { Text(successMessage ?? "") }
            .fileExporter(
                isPresented: $isExportingToFile,
                document: csvDocument,
                contentType: .commaSeparatedText,
                defaultFilename: exportFileName
            ) { result in
                switch result {
                case .success:
                    successMessage = "CSV file saved successfully."
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .fileImporter(
                isPresented: $isImportingFromFile,
                allowedContentTypes: [.commaSeparatedText, .plainText]
            ) { result in
                handleFileImportResult(result)
            }
            .sheet(isPresented: $isSharing) {
                ActivityView(items: shareItems)
            }
        }
    }

    // MARK: - Export section

    private var exportSection: some View {
        Section {
            Button {
                csvDocument = CSVDocument(content: CSVService.exportCSV(shows: viewModel.shows))
                isExportingToFile = true
            } label: {
                Label("Save to CSV File…", systemImage: "square.and.arrow.down")
            }
            .disabled(!hasShows)

            Button {
                let csv = CSVService.exportCSV(shows: viewModel.shows)
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(exportFileName)
                try? csv.write(to: tempURL, atomically: true, encoding: .utf8)
                shareItems = [tempURL]
                isSharing = true
            } label: {
                Label("Share / AirDrop…", systemImage: "square.and.arrow.up")
            }
            .disabled(!hasShows)

            if !hasShows {
                Text("Add some shows first before exporting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Export (\(viewModel.shows.count) shows)")
        } footer: {
            Text("CSV files can be opened in Excel, Numbers, or Google Sheets.")
        }
    }

    // MARK: - Import section

    private var importSection: some View {
        Section {
            Button {
                isImportingFromFile = true
            } label: {
                Label("Import from CSV File…", systemImage: "square.and.arrow.up")
            }
        } header: {
            Text("Import")
        } footer: {
            Text("Select a CSV file exported from this app or formatted with the columns shown below.")
        }
    }

    // MARK: - CSV format info

    private var csvFormatSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Required column order:")
                    .font(.caption.weight(.semibold))
                Text(CSVService.headerRow)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)

            Text("Tips:")
                .font(.caption.weight(.semibold))
            VStack(alignment: .leading, spacing: 4) {
                BulletText("Rating: 0–5 (0 = unrated)")
                BulletText("Thumbs: \"Loved It\", \"Not For Me\", or \"None\"")
                BulletText("Genres: separated by \"; \" (semicolon + space)")
                BulletText("Date format: YYYY-MM-DD (e.g. 2025-01-15)")
                BulletText("Status: \"Watched\" or \"Want to Watch\"")
            }
        } header: {
            Text("CSV Format")
        }
    }

    // MARK: - Import actions

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
            parseAndPresentImport(content)
        }
    }

    private func parseAndPresentImport(_ csvString: String) {
        do {
            let shows = try CSVService.importCSV(csvString)
            pendingShows = shows
            showMergeDialog = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Helper views

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

struct AsyncButton: View {
    @Binding var isWorking: Bool
    let label: String
    let icon: String
    let action: () async -> Void

    var body: some View {
        Button {
            Task {
                isWorking = true
                await action()
                isWorking = false
            }
        } label: {
            HStack {
                Label(label, systemImage: icon)
                Spacer()
                if isWorking {
                    ProgressView().scaleEffect(0.8)
                }
            }
        }
        .disabled(isWorking)
    }
}

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
