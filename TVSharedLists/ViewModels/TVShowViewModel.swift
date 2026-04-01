import Foundation

@MainActor
class TVShowViewModel: ObservableObject {
    @Published var shows: [TVShow] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let store = TVShowStore()

    init() {
        load()
    }

    // MARK: - Load / Save

    private func load() {
        isLoading = true
        shows = store.load().sorted { $0.addedAt > $1.addedAt }
        isLoading = false
    }

    private func persist() {
        store.save(shows)
    }

    // MARK: - CRUD

    func addShow(_ show: TVShow) {
        shows.insert(show, at: 0)
        persist()
    }

    func deleteShow(_ show: TVShow) {
        shows.removeAll { $0.id == show.id }
        persist()
    }

    func clearAllShows() {
        shows = []
        persist()
    }

    func updateShow(_ show: TVShow) {
        guard let index = shows.firstIndex(where: { $0.id == show.id }) else { return }
        shows[index] = show
        persist()
    }

    // MARK: - Bulk import

    /// Replaces all existing shows with the imported list.
    func replaceAllShows(with newShows: [TVShow]) {
        shows = newShows.sorted { $0.addedAt > $1.addedAt }
        persist()
    }

    /// Merges imported shows, skipping duplicates (matched by tvMazeId when available, otherwise by title).
    func appendShows(_ newShows: [TVShow]) {
        var result = shows
        for show in newShows {
            let isDuplicate: Bool
            if show.tvMazeId > 0 {
                isDuplicate = result.contains { $0.tvMazeId == show.tvMazeId }
            } else {
                isDuplicate = result.contains { $0.title.lowercased() == show.title.lowercased() }
            }
            if !isDuplicate {
                result.append(show)
            }
        }
        shows = result.sorted { $0.addedAt > $1.addedAt }
        persist()
    }

    /// Fetches poster URLs from TVMaze for any shows that have a valid tvMazeId but no posterURL.
    func fetchMissingPosters() {
        Task {
            let indices = shows.indices.filter { shows[$0].posterURL.isEmpty && shows[$0].tvMazeId > 0 }
            guard !indices.isEmpty else { return }

            await withTaskGroup(of: (Int, String)?.self) { group in
                for index in indices {
                    let tvMazeId = shows[index].tvMazeId
                    group.addTask {
                        guard let url = URL(string: "https://api.tvmaze.com/shows/\(tvMazeId)") else { return nil }
                        guard let (data, _) = try? await URLSession.shared.data(from: url),
                              let json = try? JSONDecoder().decode(TVMazeShowSlim.self, from: data),
                              !json.posterURL.isEmpty
                        else { return nil }
                        return (index, json.posterURL)
                    }
                }
                for await result in group {
                    if let (index, url) = result {
                        shows[index].posterURL = url
                    }
                }
            }
            persist()
        }
    }
}

// Minimal decodable used only for poster fetching
private struct TVMazeShowSlim: Decodable {
    let image: TVMazeImageSlim?
    var posterURL: String {
        let url = image?.medium ?? image?.original ?? ""
        return url.replacingOccurrences(of: "http://", with: "https://")
    }
}
private struct TVMazeImageSlim: Decodable {
    let medium: String?
    let original: String?
}
