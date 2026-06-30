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
                    .tabItem { Label("Settings", systemImage: "gearshape") }
            }
            .tint(.indigo)

            BannerAdView()
                .frame(height: 50)
                .background(Color(.tertiarySystemBackground))
        }
        .ignoresSafeArea(.keyboard)
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
                            importResultMessage = "Added \(count) show\(count == 1 ? "" : "s") to \"\(viewModel.selectedList.name)\"."
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
}

#Preview {
    ContentView()
}
