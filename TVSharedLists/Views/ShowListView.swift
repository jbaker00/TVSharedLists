import SwiftUI

struct ShowListView: View {
    @ObservedObject var viewModel: TVShowViewModel
    @State private var searchText = ""
    @State private var filter: ShowFilter = .all

    enum ShowFilter: String, CaseIterable {
        case all        = "All"
        case wantToWatch = "Want to Watch"
        case loved      = "Loved"
        case topRated   = "Top Rated"
        case notForMe   = "Pass"

        var icon: String {
            switch self {
            case .all:         return "tv"
            case .wantToWatch: return "bookmark.fill"
            case .loved:       return "hand.thumbsup.fill"
            case .topRated:    return "star.fill"
            case .notForMe:    return "hand.thumbsdown.fill"
            }
        }

        var tint: Color {
            switch self {
            case .wantToWatch: return .orange
            default:           return .indigo
            }
        }
    }

    private var filteredShows: [TVShow] {
        let base: [TVShow]
        if searchText.isEmpty {
            base = viewModel.shows
        } else {
            base = viewModel.shows.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.network.localizedCaseInsensitiveContains(searchText)
                || $0.genres.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
                || $0.notes.localizedCaseInsensitiveContains(searchText)
            }
        }

        switch filter {
        case .all:         return base
        case .wantToWatch: return base.filter { $0.wantToWatch }
        case .loved:       return base.filter { $0.thumbs == "up" }
        case .topRated:    return base.filter { $0.rating >= 4 }
        case .notForMe:    return base.filter { $0.thumbs == "down" }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading shows…").padding()
                    Spacer()
                } else if filteredShows.isEmpty {
                    emptyStateView
                } else {
                    showListContent
                }
            }
            .navigationTitle("My TV Shows")
            .searchable(text: $searchText, prompt: "Search shows, networks, notes…")
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ShowFilter.allCases, id: \.self) { option in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            filter = option
                        }
                    } label: {
                        Label(option.rawValue, systemImage: option.icon)
                            .font(.subheadline.weight(filter == option ? .semibold : .regular))
                            .foregroundStyle(filter == option ? .white : .secondary)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 9)
                            .background(
                                Capsule().fill(filter == option ? option.tint : Color(.secondarySystemBackground))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Show list

    private var showListContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredShows) { show in
                    NavigationLink(destination: ShowDetailView(show: show, viewModel: viewModel)) {
                        ShowCard(show: show)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.deleteShow(show)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            var updated = show
                            updated.wantToWatch.toggle()
                            viewModel.updateShow(updated)
                        } label: {
                            Label(show.wantToWatch ? "Mark Watched" : "Want to Watch",
                                  systemImage: show.wantToWatch ? "checkmark.circle" : "bookmark")
                        }
                        .tint(.orange)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: filter == .all && searchText.isEmpty ? "tv.slash" : "magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.secondary.opacity(0.3))
            Text(filter == .all && searchText.isEmpty ? "No Shows Yet" : "No Matches")
                .font(.title2.bold())
                .foregroundStyle(.secondary)
            Text(filter == .all && searchText.isEmpty
                 ? "Tap \"Add Show\" to get started"
                 : "Try a different search or filter")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(40)
    }
}
