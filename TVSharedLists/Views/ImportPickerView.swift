import SwiftUI

/// Shown when importing shows from a .tvlist or CSV file.
/// New shows are pre-selected; shows already in the user's list are pre-deselected
/// and marked with an "Already in list" badge.
struct ImportPickerView: View {
    let incomingShows: [TVShow]
    let existingShows: [TVShow]
    let onImport: ([TVShow]) -> Void
    let onCancel: () -> Void

    @State private var selectedIDs: Set<UUID>

    // MARK: - Init

    init(
        incomingShows: [TVShow],
        existingShows: [TVShow],
        onImport: @escaping ([TVShow]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.incomingShows = incomingShows
        self.existingShows = existingShows
        self.onImport = onImport
        self.onCancel = onCancel
        // Pre-select only shows that aren't already in the list.
        _selectedIDs = State(initialValue: Set(
            incomingShows
                .filter { !Self.isDuplicate($0, in: existingShows) }
                .map { $0.id }
        ))
    }

    // MARK: - Helpers

    private static func isDuplicate(_ show: TVShow, in list: [TVShow]) -> Bool {
        if show.tmdbId > 0   { return list.contains { $0.tmdbId == show.tmdbId } }
        if show.tvMazeId > 0 { return list.contains { $0.tvMazeId == show.tvMazeId } }
        return list.contains { $0.title.lowercased() == show.title.lowercased() }
    }

    private func isDuplicate(_ show: TVShow) -> Bool {
        Self.isDuplicate(show, in: existingShows)
    }

    private var newShows: [TVShow]       { incomingShows.filter { !isDuplicate($0) } }
    private var duplicateShows: [TVShow] { incomingShows.filter { isDuplicate($0) } }
    private var allSelected: Bool        { incomingShows.allSatisfy { selectedIDs.contains($0.id) } }
    private var selectedCount: Int       { selectedIDs.count }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                summaryBanner
                Divider()
                showList
            }
            .navigationTitle("Choose Shows to Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(allSelected ? "Deselect All" : "Select All") {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedIDs = allSelected ? [] : Set(incomingShows.map { $0.id })
                        }
                    }
                    .font(.subheadline)
                }
            }
            .safeAreaInset(edge: .bottom) {
                importButton
            }
        }
    }

    // MARK: - Subviews

    private var summaryBanner: some View {
        HStack {
            Label("\(incomingShows.count) show\(incomingShows.count == 1 ? "" : "s") in file",
                  systemImage: "list.bullet")
            Spacer()
            if !duplicateShows.isEmpty {
                Label("\(duplicateShows.count) already in your list",
                      systemImage: "checkmark.circle")
                    .foregroundStyle(.orange)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }

    private var showList: some View {
        List {
            if !newShows.isEmpty {
                Section("New (\(newShows.count))") {
                    ForEach(newShows) { show in
                        ShowPickerRow(
                            show: show,
                            isDuplicate: false,
                            isSelected: selectedIDs.contains(show.id)
                        ) { toggle(show) }
                    }
                }
            }
            if !duplicateShows.isEmpty {
                Section("Already in your list (\(duplicateShows.count))") {
                    ForEach(duplicateShows) { show in
                        ShowPickerRow(
                            show: show,
                            isDuplicate: true,
                            isSelected: selectedIDs.contains(show.id)
                        ) { toggle(show) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var importButton: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                onImport(incomingShows.filter { selectedIDs.contains($0.id) })
            } label: {
                Text(selectedCount == 0
                     ? "Select Shows to Import"
                     : "Import \(selectedCount) Show\(selectedCount == 1 ? "" : "s")")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedCount == 0 ? Color(.systemGray4) : Color.indigo)
                    .foregroundStyle(selectedCount == 0 ? Color.secondary : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .disabled(selectedCount == 0)
        }
        .background(Color(.systemBackground))
    }

    private func toggle(_ show: TVShow) {
        if selectedIDs.contains(show.id) {
            selectedIDs.remove(show.id)
        } else {
            selectedIDs.insert(show.id)
        }
    }
}

// MARK: - Row

private struct ShowPickerRow: View {
    let show: TVShow
    let isDuplicate: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.indigo : Color(.systemGray3))
                    .animation(.easeInOut(duration: 0.15), value: isSelected)

                posterThumbnail

                VStack(alignment: .leading, spacing: 3) {
                    Text(show.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(isDuplicate ? .secondary : .primary)
                        .lineLimit(2)

                    if !show.network.isEmpty {
                        Text(show.network)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if show.rating > 0 {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= show.rating ? "star.fill" : "star")
                                    .font(.system(size: 9))
                                    .foregroundStyle(
                                        star <= show.rating ? Color.yellow : Color(.systemGray4)
                                    )
                            }
                        }
                    }
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(isDuplicate ? Color(.systemGray6).opacity(0.6) : Color.clear)
    }

    private var posterThumbnail: some View {
        Group {
            if !show.posterURL.isEmpty, let url = URL(string: show.posterURL) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color(.systemGray5)
                }
                .frame(width: 36, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 36, height: 54)
                    .overlay {
                        Image(systemName: show.mediaType == "movie" ? "film" : "tv")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .opacity(isDuplicate ? 0.45 : 1.0)
    }
}
