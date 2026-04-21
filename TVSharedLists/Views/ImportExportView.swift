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
    @State private var linkText = ""
    @State private var isImportingFromLink = false

    // Feedback
    @State private var errorMessage: String?

    private var hasShows: Bool { !viewModel.shows.isEmpty }

    private var exportDateString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
    private var csvFileName: String    { "TVShows-\(exportDateString).csv" }
    private var tvlistFileName: String { "TVShows-\(exportDateString).tvlist" }

    var body: some View {
        NavigationStack {
            List {
                exportSection
                importSection
                csvFormatSection
            }
            .navigationTitle("Import / Export")
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
                if case .failure(let error) = result {
                    errorMessage = error.localizedDescription
                }
            }
            .fileImporter(
                isPresented: $isImportingFromFile,
                allowedContentTypes: [.tvList, .commaSeparatedText, .plainText]
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
            // Share .tvlist — the primary sharing format for friends
            Button {
                guard let data = TVListService.encode(viewModel.shows) else { return }
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(tvlistFileName)
                try? data.write(to: tempURL)
                shareItems = [tempURL]
                isSharing = true
            } label: {
                Label("Share with Friends (.tvlist)…", systemImage: "person.2.fill")
            }
            .disabled(!hasShows)

            // CSV for spreadsheet tools
            Button {
                let csv = CSVService.exportCSV(shows: viewModel.shows)
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(csvFileName)
                try? csv.write(to: tempURL, atomically: true, encoding: .utf8)
                shareItems = [tempURL]
                isSharing = true
            } label: {
                Label("Share as CSV…", systemImage: "square.and.arrow.up")
            }
            .disabled(!hasShows)

            Button {
                csvDocument = CSVDocument(content: CSVService.exportCSV(shows: viewModel.shows))
                isExportingToFile = true
            } label: {
                Label("Save CSV to Files…", systemImage: "square.and.arrow.down")
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
            Text("Share a .tvlist file with friends — they can open it in the app and choose exactly which shows to import.")
        }
    }

    // MARK: - Import section

    private var importSection: some View {
        Section {
            Button {
                isImportingFromFile = true
            } label: {
                Label("Import from File…", systemImage: "square.and.arrow.up")
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Import from URL")
                    .font(.subheadline.weight(.medium))

                TextField("Paste a link to a CSV file…", text: $linkText)
                    .autocorrectionDisabled()
                    .autocapitalization(.none)
                    .keyboardType(.URL)
                    .font(.caption)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10).fill(Color(.tertiarySystemBackground))
                    )

                AsyncButton(isWorking: $isImportingFromLink, label: "Import from Link", icon: "link.badge.plus") {
                    await importFromLink()
                }
                .disabled(linkText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Import")
        } footer: {
            Text("Accepts .tvlist files (from friends using this app) or CSV files. Paste any Google Drive or Sheets share link to import directly from a URL.")
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

    // MARK: - Import handlers

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

            if url.pathExtension.lowercased() == "tvlist" {
                guard let data = try? Data(contentsOf: url),
                      let shows = TVListService.decode(from: data)
                else {
                    errorMessage = "Could not read the .tvlist file."
                    return
                }
                viewModel.pendingImportShows = shows
            } else {
                guard let content = try? String(contentsOf: url, encoding: .utf8) else {
                    errorMessage = "Could not read the file. Make sure it is a plain-text CSV."
                    return
                }
                parseAndPresentImport(content)
            }
        }
    }

    private func importFromLink() async {
        let trimmed = linkText.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: trimmed) else {
            errorMessage = "That doesn't look like a valid URL. Make sure it starts with https://"
            return
        }
        let downloadURL = Self.directDownloadURL(from: url)
        do {
            let (data, response) = try await URLSession.shared.data(from: downloadURL)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                errorMessage = "The server returned HTTP \(http.statusCode). Check the link is correct and the file is set to public."
                return
            }
            guard let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                errorMessage = "Could not decode the downloaded file as text."
                return
            }
            parseAndPresentImport(content)
        } catch {
            errorMessage = "Download failed: \(error.localizedDescription)"
        }
    }

    private func parseAndPresentImport(_ csvString: String) {
        do {
            let shows = try CSVService.importCSV(csvString)
            viewModel.pendingImportShows = shows
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Converts Google Drive / Sheets share links to direct-download URLs.
    private static func directDownloadURL(from url: URL) -> URL {
        let str = url.absoluteString

        if str.contains("drive.google.com/file/d/"),
           let fileID = str
               .components(separatedBy: "/file/d/").last?
               .components(separatedBy: "/").first?
               .components(separatedBy: "?").first,
           !fileID.isEmpty {
            return URL(string: "https://drive.google.com/uc?export=download&id=\(fileID)") ?? url
        }

        if str.contains("drive.google.com/open"),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let id = components.queryItems?.first(where: { $0.name == "id" })?.value {
            return URL(string: "https://drive.google.com/uc?export=download&id=\(id)") ?? url
        }

        if str.contains("spreadsheets/d/"),
           let sheetID = str
               .components(separatedBy: "/spreadsheets/d/").last?
               .components(separatedBy: "/").first?
               .components(separatedBy: "?").first,
           !sheetID.isEmpty {
            return URL(string: "https://docs.google.com/spreadsheets/d/\(sheetID)/export?format=csv") ?? url
        }

        return url
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
                if isWorking { ProgressView().scaleEffect(0.8) }
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
