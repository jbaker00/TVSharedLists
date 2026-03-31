import SwiftUI

struct AddShowView: View {
    @ObservedObject var viewModel: TVShowViewModel
    @StateObject private var tvMaze = TVMazeService()

    // Search state
    @State private var searchQuery   = ""
    @State private var selectedShow: TVMazeShow?
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
        selectedShow != nil || !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    searchSection

                    if showingResults && !tvMaze.searchResults.isEmpty {
                        searchResultsList
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if let show = selectedShow {
                        selectedShowCard(show)
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
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedShow?.id)
                .animation(.spring(response: 0.3), value: wantToWatch)
            }
            .navigationTitle("Add a Show")
            .navigationBarTitleDisplayMode(.large)
            .onChange(of: searchQuery) { newValue in
                tvMaze.search(query: newValue)
                showingResults = !newValue.trimmingCharacters(in: .whitespaces).isEmpty
                if newValue.isEmpty { selectedShow = nil }
            }
            .overlay {
                if showingSuccess { successOverlay }
            }
        }
    }

    // MARK: - Search field

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Search for a TV Show")
                .font(.headline)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Type a show name…", text: $searchQuery)
                    .focused($searchFocused)
                    .autocorrectionDisabled()
                    .submitLabel(.search)

                if tvMaze.isSearching {
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

            if selectedShow == nil && !searchQuery.isEmpty && !showingResults {
                Text("No show selected — will save with title only")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Inline search results

    private var searchResultsList: some View {
        VStack(spacing: 0) {
            ForEach(tvMaze.searchResults) { show in
                Button { selectShow(show) } label: {
                    HStack(spacing: 12) {
                        PosterImageView(url: show.posterURL, width: 38, height: 56)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(show.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            HStack(spacing: 6) {
                                if show.networkName != "Unknown" {
                                    Text(show.networkName).font(.caption).foregroundStyle(.secondary)
                                }
                                if !show.genres.isEmpty {
                                    Text("·").font(.caption).foregroundStyle(.tertiary)
                                    Text(show.genres.prefix(2).joined(separator: ", "))
                                        .font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                                }
                            }
                        }

                        Spacer()
                        Image(systemName: "plus.circle").foregroundStyle(.indigo).font(.subheadline)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                if show.id != tvMaze.searchResults.last?.id {
                    Divider().padding(.leading, 64)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    // MARK: - Selected show card

    private func selectedShowCard(_ show: TVMazeShow) -> some View {
        HStack(alignment: .top, spacing: 16) {
            PosterImageView(url: show.posterURL, width: 80, height: 120)

            VStack(alignment: .leading, spacing: 6) {
                Text(show.name).font(.title3.bold()).lineLimit(2)

                if show.networkName != "Unknown" {
                    Label(show.networkName, systemImage: "tv.fill")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if !show.genres.isEmpty {
                    Text(show.genres.prefix(3).joined(separator: " · "))
                        .font(.caption).foregroundStyle(.tertiary)
                }
                if let status = show.status {
                    let running = status.lowercased().contains("running") || status.lowercased().contains("continu")
                    Label(status, systemImage: running ? "play.circle.fill" : "stop.circle")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(running ? .green : .secondary)
                }
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            Button { withAnimation { selectedShow = nil; searchQuery = "" } } label: {
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

    // MARK: - Rating section (only shown when not wantToWatch)

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
        Button { submitShow() } label: {
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
                Text(wantToWatch ? "Added to Watchlist!" : "Show Added!")
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

    private func selectShow(_ show: TVMazeShow) {
        withAnimation {
            selectedShow = show
            searchQuery = show.name
            showingResults = false
            searchFocused = false
        }
        tvMaze.clear()
    }

    private func clearSearch() {
        searchQuery = ""
        selectedShow = nil
        tvMaze.clear()
        showingResults = false
    }

    private func submitShow() {
        let title = selectedShow?.name ?? searchQuery.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }

        let newShow = TVShow(
            title:       title,
            network:     selectedShow?.networkName ?? "Unknown",
            posterURL:   selectedShow?.posterURL ?? "",
            summary:     selectedShow?.cleanSummary ?? "",
            genres:      selectedShow?.genres ?? [],
            rating:      wantToWatch ? 0 : rating,
            thumbs:      wantToWatch ? "none" : thumbs,
            notes:       notes.trimmingCharacters(in: .whitespacesAndNewlines),
            addedAt:     Date(),
            tvMazeId:    selectedShow?.id ?? -1,
            wantToWatch: wantToWatch
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
        selectedShow = nil
        rating = 0
        thumbs = "none"
        notes = ""
        wantToWatch = false
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
