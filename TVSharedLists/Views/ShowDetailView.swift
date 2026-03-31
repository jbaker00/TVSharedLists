import SwiftUI

struct ShowDetailView: View {
    @State private var show: TVShow
    @ObservedObject var viewModel: TVShowViewModel
    @State private var showingEditSheet = false

    init(show: TVShow, viewModel: TVShowViewModel) {
        _show = State(initialValue: show)
        self.viewModel = viewModel
    }

    private var thumbsInfo: (icon: String, color: Color, label: String)? {
        switch show.thumbs {
        case "up":   return ("hand.thumbsup.fill",   .green, "Loved It")
        case "down": return ("hand.thumbsdown.fill", .red,   "Not For Me")
        default:     return nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroSection
                contentSection
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEditSheet = true }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditShowSheet(show: show) { updated in
                show = updated
                viewModel.updateShow(updated)
            }
        }
    }

    // MARK: - Hero Image

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let url = URL(string: show.posterURL), !show.posterURL.isEmpty {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            heroPlaceholder
                        }
                    }
                } else {
                    heroPlaceholder
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 400)
            .clipped()

            LinearGradient(
                stops: [
                    .init(color: .clear,              location: 0.25),
                    .init(color: .black.opacity(0.9), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                if show.wantToWatch {
                    Label("Want to Watch", systemImage: "bookmark.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.orange.opacity(0.85)))
                }
                if !show.network.isEmpty, show.network != "Unknown" {
                    Label(show.network, systemImage: "tv.fill")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Text(show.title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(height: 400)
    }

    private var heroPlaceholder: some View {
        LinearGradient(
            colors: [Color.indigo.opacity(0.7), Color.purple.opacity(0.5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "tv")
                .font(.system(size: 72))
                .foregroundStyle(.white.opacity(0.25))
        )
    }

    // MARK: - Content

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            if !show.genres.isEmpty { genreChips }

            Divider()
            if !show.wantToWatch { ratingRow }
            if !show.notes.isEmpty { notesCard }
            if !show.summary.isEmpty { summaryCard }

            HStack {
                Image(systemName: "calendar").foregroundStyle(.secondary)
                Text("Added \(show.addedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(20)
    }

    private var genreChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(show.genres, id: \.self) { genre in
                    Text(genre)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.indigo.opacity(0.85)))
                }
            }
        }
    }

    @ViewBuilder
    private var ratingRow: some View {
        HStack(spacing: 28) {
            if show.rating > 0 {
                VStack(spacing: 5) {
                    StarRatingDisplayView(rating: show.rating, starSize: 20, spacing: 4)
                    Text("\(show.rating) / 5").font(.caption).foregroundStyle(.secondary)
                }
            }

            if let thumbs = thumbsInfo {
                HStack(spacing: 8) {
                    Image(systemName: thumbs.icon).font(.title2).foregroundStyle(thumbs.color)
                    Text(thumbs.label).font(.subheadline).foregroundStyle(.secondary)
                }
            }

            if show.rating == 0 && show.thumbs == "none" {
                Text("No rating yet").font(.subheadline).foregroundStyle(.tertiary)
            }

            Spacer()
        }
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes", systemImage: "note.text").font(.headline)
            Text(show.notes)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About").font(.headline)
            Text(show.summary)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(5)
        }
    }
}

// MARK: - Edit Sheet

struct EditShowSheet: View {
    @Environment(\.dismiss) private var dismiss

    let show: TVShow
    let onSave: (TVShow) -> Void

    @State private var wantToWatch: Bool
    @State private var rating: Int
    @State private var thumbs: String
    @State private var notes: String
    @FocusState private var notesFocused: Bool

    init(show: TVShow, onSave: @escaping (TVShow) -> Void) {
        self.show = show
        self.onSave = onSave
        _wantToWatch = State(initialValue: show.wantToWatch)
        _rating      = State(initialValue: show.rating)
        _thumbs      = State(initialValue: show.thumbs)
        _notes       = State(initialValue: show.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Status") {
                    HStack(spacing: 12) {
                        StatusButton(
                            label: "Watched",
                            icon: "checkmark.circle.fill",
                            color: .indigo,
                            isSelected: !wantToWatch
                        ) { withAnimation { wantToWatch = false } }

                        StatusButton(
                            label: "Want to Watch",
                            icon: "bookmark.fill",
                            color: .orange,
                            isSelected: wantToWatch
                        ) { withAnimation { wantToWatch = true } }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.clear)
                }

                if !wantToWatch {
                    Section("Star Rating") {
                        HStack {
                            StarRatingView(rating: $rating)
                            Spacer()
                            if rating > 0 {
                                Button("Clear") { withAnimation { rating = 0 } }
                                    .font(.subheadline)
                                    .foregroundStyle(.indigo)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Section("Recommendation") {
                        HStack(spacing: 14) {
                            ThumbButton(label: "Love It", icon: "hand.thumbsup.fill", color: .green, isSelected: thumbs == "up") {
                                withAnimation { thumbs = thumbs == "up" ? "none" : "up" }
                            }
                            ThumbButton(label: "Not For Me", icon: "hand.thumbsdown.fill", color: .red, isSelected: thumbs == "down") {
                                withAnimation { thumbs = thumbs == "down" ? "none" : "down" }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.clear)
                    }
                }

                Section("Notes") {
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
                            .frame(minHeight: 120)
                            .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Edit \(show.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        var updated = show
                        updated.wantToWatch = wantToWatch
                        updated.rating = wantToWatch ? 0 : rating
                        updated.thumbs = wantToWatch ? "none" : thumbs
                        updated.notes  = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(updated)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}
