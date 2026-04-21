import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TVShowViewModel()
    @State private var importResultMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                ShowListView(viewModel: viewModel)
                    .tabItem { Label("My List", systemImage: "list.bullet") }

                AddShowView(viewModel: viewModel)
                    .tabItem { Label("Add", systemImage: "plus.circle.fill") }

                ImportExportView(viewModel: viewModel)
                    .tabItem { Label("Import / Export", systemImage: "arrow.up.arrow.down.circle") }
            }
            .tint(.indigo)

            BannerAdView()
                .frame(height: 50)
                .background(Color(.tertiarySystemBackground))
        }
        .ignoresSafeArea(.keyboard)
        // Handle .tvlist files opened from Files, AirDrop, Messages, etc.
        .onOpenURL { url in
            handleIncomingFile(url)
        }
        // Import picker — driven from both in-app imports and external file opens.
        .sheet(isPresented: Binding(
            get: { viewModel.pendingImportShows != nil },
            set: { if !$0 { viewModel.pendingImportShows = nil } }
        )) {
            if let shows = viewModel.pendingImportShows {
                ImportPickerView(
                    incomingShows: shows,
                    existingShows: viewModel.shows,
                    onImport: { selected in
                        let count = selected.count
                        viewModel.appendShows(selected)
                        viewModel.fetchMissingPosters()
                        viewModel.pendingImportShows = nil
                        if count > 0 {
                            importResultMessage = "Added \(count) show\(count == 1 ? "" : "s") to your list."
                        }
                    },
                    onCancel: {
                        viewModel.pendingImportShows = nil
                    }
                )
            }
        }
        .alert("Import Complete", isPresented: Binding(
            get: { importResultMessage != nil },
            set: { if !$0 { importResultMessage = nil } }
        )) {
            Button("OK") { importResultMessage = nil }
        } message: {
            Text(importResultMessage ?? "")
        }
    }

    // MARK: - External file handling

    private func handleIncomingFile(_ url: URL) {
        guard url.pathExtension.lowercased() == "tvlist" else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let shows = TVListService.decode(from: data),
              !shows.isEmpty
        else { return }
        viewModel.pendingImportShows = shows
    }
}

#Preview {
    ContentView()
}
