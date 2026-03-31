import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TVShowViewModel()

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                ShowListView(viewModel: viewModel)
                    .tabItem { Label("Shows", systemImage: "tv.fill") }

                AddShowView(viewModel: viewModel)
                    .tabItem { Label("Add Show", systemImage: "plus.circle.fill") }

                ImportExportView(viewModel: viewModel)
                    .tabItem { Label("Import / Export", systemImage: "arrow.up.arrow.down.circle") }
            }
            .tint(.indigo)

            BannerAdView()
                .frame(height: 50)
                .background(Color(.tertiarySystemBackground))
        }
        .ignoresSafeArea(.keyboard)
    }
}

#Preview {
    ContentView()
}
