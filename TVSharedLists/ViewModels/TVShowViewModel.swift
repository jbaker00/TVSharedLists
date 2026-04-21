import Foundation
import StoreKit
import UIKit

@MainActor
class TVShowViewModel: ObservableObject {
    @Published var shows: [TVShow] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// Non-nil while the import picker sheet is open. Set by ImportExportView or the onOpenURL handler.
    @Published var pendingImportShows: [TVShow]?

    private let store = TVShowStore()
    private let reviewRequestedKey = "reviewRequested"

    init() {
        load()
        fetchMissingPosters()
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
        if show.posterURL.isEmpty {
            fetchMissingPosters()
        }
        requestReviewIfAppropriate()
    }

    // Prompt for a review after the user has added 3 shows, once per install.
    private func requestReviewIfAppropriate() {
        guard shows.count == 3,
              !UserDefaults.standard.bool(forKey: reviewRequestedKey)
        else { return }
        UserDefaults.standard.set(true, forKey: reviewRequestedKey)
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
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
            if show.tmdbId > 0 {
                isDuplicate = result.contains { $0.tmdbId == show.tmdbId }
            } else if show.tvMazeId > 0 {
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

    /// Fetches poster URLs (from TVMaze or TMDB) for any shows that have no posterURL.
    /// Uses ID-based lookup so concurrent inserts don't corrupt indices.
    func fetchMissingPosters() {
        Task {
            // Snapshot IDs + metadata at the time of the call; never store raw indices
            let targets = shows
                .filter { $0.posterURL.isEmpty }
                .map { (id: $0.id, tvMazeId: $0.tvMazeId, tmdbId: $0.tmdbId, mediaType: $0.mediaType) }
            guard !targets.isEmpty else { return }

            await withTaskGroup(of: (UUID, String)?.self) { group in
                for target in targets {
                    group.addTask {
                        if target.tvMazeId > 0 {
                            guard let url = URL(string: "https://api.tvmaze.com/shows/\(target.tvMazeId)"),
                                  let (data, _) = try? await URLSession.shared.data(from: url),
                                  let json = try? JSONDecoder().decode(TVMazeShowSlim.self, from: data),
                                  !json.posterURL.isEmpty
                            else { return nil }
                            return (target.id, json.posterURL)
                        } else if target.tmdbId > 0 {
                            let path = target.mediaType == "movie"
                                ? "movie/\(target.tmdbId)"
                                : "tv/\(target.tmdbId)"
                            guard let url = URL(string: "https://api.themoviedb.org/3/\(path)") else { return nil }
                            var request = URLRequest(url: url)
                            request.setValue("Bearer \(TMDBSecrets.readAccessToken)", forHTTPHeaderField: "Authorization")
                            guard let (data, _) = try? await URLSession.shared.data(for: request),
                                  let json = try? JSONDecoder().decode(TMDBShowSlim.self, from: data),
                                  let posterPath = json.posterPath, !posterPath.isEmpty
                            else { return nil }
                            return (target.id, "https://image.tmdb.org/t/p/w342\(posterPath)")
                        }
                        return nil
                    }
                }
                for await result in group {
                    if let (id, url) = result,
                       let idx = shows.firstIndex(where: { $0.id == id }) {
                        shows[idx].posterURL = url
                    }
                }
            }
            persist()
        }
    }
}

// Minimal decodables used only for poster fetching
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
private struct TMDBShowSlim: Decodable {
    let posterPath: String?
    enum CodingKeys: String, CodingKey { case posterPath = "poster_path" }
}
