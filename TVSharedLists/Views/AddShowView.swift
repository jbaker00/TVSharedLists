import SwiftUI

struct AddShowView: View {
    @ObservedObject var viewModel: TVShowViewModel
    @StateObject private var tmdb   = TMDBService()
    @StateObject private var tvMaze = TVMazeService()

    // Search state
    @State private var searchQuery    = ""
    @State private var selectedResult: MediaSearchResult?
    @State private var showingResults = false

    // Show details
    @State private var rating      = 0
    @State private var thumbs      = "none"
    @State private var notes       = ""
    @State private var wantToWatch = false

    // UI state
    @State private var showingSuccess = false
    @FocusState private var searchFocused: Bool
    @FocusState private var notesFocused: Bool

    private var hasTitle: Bool {
        selectedResult != nil || !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// TMDB multi results are primary; TVMaze is the fallback when TMDB returns nothing.
    private var currentResults: [MediaSearchResult] {
        tmdb.multiResults.isEmpty ? tvMaze.searchResults.map(\.asMediaResult) : tmdb.multiResults
    }

    private var isSearching: Bool {
        tmdb.isSearching || tvMaze.isSearching
    }

    private var usingTVMazeFallback: Bool {
        !searchQuery.isEmpty && !tmdb.isSearching && tmdb.multiResults.isEmpty && !tvMaze.searchResults.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    searchSection

                    if showingResults && !currentResults.isEmpty {
                        searchResultsList
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if let result = selectedResult {
                        selectedResultCard(result)
                            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
                    }

                    watchStatusSection
                    if !wantToWatch { ratingSection }
                    notesSection
                    submitButton
                        .padding(.bottom, 8)
                }
                .padding(20)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showingResults)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedResult?.id)
                .animation(.spring(response: 0.3), value: wantToWatch)
            }
            .navigationTitle("Add to List")
            .navigationBarTitleDisplayMode(.large)
            .onChange(of: searchQuery) { newValue in
                selectedResult = nil
                tvMaze.clear()
                tmdb.clear()

                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                showingResults = !trimmed.isEmpty

                if trimmed.isEmpty {
                    showingResults = false
                } else {
                    tmdb.searchMulti(query: trimmed)
                }
            }
            // When TMDB finishes with no results, fall back to TVMaze (TV only)
            .onChange(of: tmdb.isSearching) { searching in
                if !searching && tmdb.multiResults.isEmpty && !searchQuery.isEmpty {
                    tvMaze.search(query: searchQuery)
                }
            }
            .overlay {
                if showingSuccess { successOverlay }
            }
        }
    }

    // MARK: - Search field

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Search for a Show or Movie")
                .font(.headline)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Type a title…", text: $searchQuery)
                    .focused($searchFocused)
                    .autocorrectionDisabled()
                    .submitLabel(.search)

                if isSearching {
                    ProgressView().scaleEffect(0.75)
                } else if !searchQuery.isEmpty {
                    Button { clearSearch() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))

            if selectedResult == nil && !searchQuery.isEmpty && !showingResults {
                Text("No result selected — will save with title only")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Inline search results

    private var searchResultsList: some View {
        VStack(spacing: 0) {
            if usingTVMazeFallback {
                HStack {
                    Text("No TMDB matches — showing TVMaze TV results")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 4)
            }

            ForEach(currentResults) { result in
                Button { selectResult(result) } label: {
                    HStack(spacing: 12) {
                        PosterImageView(url: result.posterURL, width: 38, height: 56,
                                        mediaType: result.mediaType)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(result.displayTitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            HStack(spacing: 6) {
                                if !result.network.isEmpty && result.network != "Unknown" {
                                    Text(result.network).font(.caption).foregroundStyle(.secondary)
                                }
                                if !result.genres.isEmpty {
                                    if !result.network.isEmpty && result.network != "Unknown" {
                                        Text("·").font(.caption).foregroundStyle(.tertiary)
                                    }
                                    Text(result.genres.prefix(2).joined(separator: ", "))
                                        .font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                                }
                            }
                        }

                        Spacer()

                        // Small badge distinguishing movies from TV in mixed results
                        if result.mediaType == "movie" {
                            Image(systemName: "film")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Image(systemName: "plus.circle").foregroundStyle(.indigo).font(.subheadline)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                if result.id != currentResults.last?.id {
                    Divider().padding(.leading, 64)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    // MARK: - Selected result card

    private func selectedResultCard(_ result: MediaSearchResult) -> some View {
        HStack(alignment: .top, spacing: 16) {
            PosterImageView(url: result.posterURL, width: 80, height: 120,
                            mediaType: result.mediaType)

            VStack(alignment: .leading, spacing: 6) {
                Text(result.displayTitle).font(.title3.bold()).lineLimit(2)

                if !result.network.isEmpty && result.network != "Unknown" {
                    Label(result.network,
                          systemImage: result.mediaType == "movie" ? "film" : "tv.fill")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if !result.genres.isEmpty {
                    Text(result.genres.prefix(3).joined(separator: " · "))
                        .font(.caption).foregroundStyle(.tertiary)
                }
                if let status = result.status {
                    let running = status.lowercased().contains("running") || status.lowercased().contains("continu")
                    Label(status, systemImage: running ? "play.circle.fill" : "stop.circle")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(running ? .green : .secondary)
                }
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            Button { withAnimation { selectedResult = nil; searchQuery = "" } } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(Color(.tertiaryLabel))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    // MARK: - Watch status toggle

    private var watchStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status").font(.headline)

            HStack(spacing: 12) {
                StatusButton(
                    label: "I've Watched This",
                    icon: "checkmark.circle.fill",
                    color: .indigo,
                    isSelected: !wantToWatch
                ) {
                    withAnimation(.spring(response: 0.25)) { wantToWatch = false }
                }

                StatusButton(
                    label: "Want to Watch",
                    icon: "bookmark.fill",
                    color: .orange,
                    isSelected: wantToWatch
                ) {
                    withAnimation(.spring(response: 0.25)) { wantToWatch = true }
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    // MARK: - Rating section

    private var ratingSection: some View {
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Star Rating").font(.headline)
                    Spacer()
                    if rating > 0 {
                        Button("Clear") { withAnimation { rating = 0 } }
                            .font(.subheadline).foregroundStyle(.indigo)
                    }
                }
                HStack {
                    StarRatingView(rating: $rating)
                    Spacer()
                    if rating > 0 {
                        Text("\(rating) / 5").font(.subheadline).foregroundStyle(.secondary)
                            .transition(.opacity)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Would You Recommend It?").font(.headline)
                HStack(spacing: 14) {
                    ThumbButton(label: "Love It", icon: "hand.thumbsup.fill", color: .green, isSelected: thumbs == "up") {
                        withAnimation(.spring(response: 0.25)) { thumbs = thumbs == "up" ? "none" : "up" }
                    }
                    ThumbButton(label: "Not For Me", icon: "hand.thumbsdown.fill", color: .red, isSelected: thumbs == "down") {
                        withAnimation(.spring(response: 0.25)) { thumbs = thumbs == "down" ? "none" : "down" }
                    }
                    Spacer()
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    // MARK: - Notes section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Notes", systemImage: "note.text")
                .font(.headline)

            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text("Add your thoughts, where you watched, who recommended it…")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $notes)
                    .focused($notesFocused)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    // MARK: - Submit

    private var submitButton: some View {
        Button { submitEntry() } label: {
            Label("Add to List", systemImage: "plus.circle.fill")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(hasTitle ? Color.indigo : Color(.systemFill))
                )
        }
        .disabled(!hasTitle)
        .animation(.default, value: hasTitle)
    }

    // MARK: - Success overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: wantToWatch ? "bookmark.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(wantToWatch ? .orange : .green)
                Text(wantToWatch ? "Added to Watchlist!" : (selectedResult?.mediaType == "movie" ? "Movie Added!" : "Show Added!"))
                    .font(.title2.bold())
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 30)
            )
            .transition(.opacity.combined(with: .scale(scale: 0.85)))
        }
        .animation(.spring(response: 0.4), value: showingSuccess)
    }

    // MARK: - Actions

    private func selectResult(_ result: MediaSearchResult) {
        withAnimation {
            selectedResult = result
            searchQuery = result.displayTitle
            showingResults = false
            searchFocused = false
        }
        tmdb.clear()
        tvMaze.clear()
    }

    private func clearSearch() {
        searchQuery = ""
        selectedResult = nil
        tmdb.clear()
        tvMaze.clear()
        showingResults = false
    }

    private func submitEntry() {
        let title: String
        let network: String
        let posterURL: String
        let summary: String
        let genres: [String]
        let tvMazeId: Int
        let tmdbId: Int
        let resolvedMediaType: String

        if let result = selectedResult {
            title             = result.displayTitle
            network           = result.network
            posterURL         = result.posterURL
            summary           = result.summary
            genres            = result.genres
            tvMazeId          = result.tvMazeId
            tmdbId            = result.tmdbId
            resolvedMediaType = result.mediaType
        } else {
            title             = searchQuery.trimmingCharacters(in: .whitespaces)
            network           = "Unknown"
            posterURL         = ""
            summary           = ""
            genres            = []
            tvMazeId          = -1
            tmdbId            = -1
            resolvedMediaType = "tv"
        }

        guard !title.isEmpty else { return }

        let newShow = TVShow(
            title:       title,
            network:     network,
            posterURL:   posterURL,
            summary:     summary,
            genres:      genres,
            rating:      wantToWatch ? 0 : rating,
            thumbs:      wantToWatch ? "none" : thumbs,
            notes:       notes.trimmingCharacters(in: .whitespacesAndNewlines),
            addedAt:     Date(),
            tvMazeId:    tvMazeId,
            wantToWatch: wantToWatch,
            mediaType:   resolvedMediaType,
            tmdbId:      tmdbId
        )

        viewModel.addShow(newShow)
        withAnimation(.spring(response: 0.4)) { showingSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { showingSuccess = false }
            resetForm()
        }
    }

    private func resetForm() {
        searchQuery = ""
        selectedResult = nil
        rating = 0
        thumbs = "none"
        notes = ""
        wantToWatch = false
        tmdb.clear()
        tvMaze.clear()
        showingResults = false
    }
}

// MARK: - Status button

struct StatusButton: View {
    let label: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.subheadline)
                Text(label).font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isSelected ? color : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? color.opacity(0.12) : Color(.tertiarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isSelected ? color.opacity(0.5) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Thumb button

struct ThumbButton: View {
    let label: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title2)
                Text(label).font(.caption.weight(.semibold))
            }
            .foregroundStyle(isSelected ? color : .secondary)
            .padding(.horizontal, 22)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? color.opacity(0.15) : Color(.tertiarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isSelected ? color.opacity(0.6) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isSelected)
    }
}
