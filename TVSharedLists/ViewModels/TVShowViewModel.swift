import Combine
import FirebaseAnalytics
import Foundation
import StoreKit
import UIKit

@MainActor
class TVShowViewModel: ObservableObject {
    @Published var pendingImportShows: [TVShow]?

    let manager: TVCloudKitManager
    private var cancellables = Set<AnyCancellable>()
    private let reviewRequestedKey = "reviewRequested"

    init() {
        manager = TVCloudKitManager()
        // Relay manager's published changes so views observing this ViewModel refresh too
        manager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        Task { await manager.refreshIfNeeded() }
        fetchMissingPosters()
    }

    // MARK: - Forwarded from manager

    var shows: [TVShow] { manager.showsForSelectedList }
    var allShows: [TVShow] { manager.shows }
    var lists: [TVList] { manager.lists }
    var selectedList: TVList {
        get { manager.selectedList }
        set { manager.selectedList = newValue }
    }
    var syncStatus: SyncStatus { manager.syncStatus }
    var iCloudAvailable: Bool { manager.iCloudAvailable }
    var localOnly: Bool {
        get { manager.localOnly }
        set { manager.localOnly = newValue }
    }
    var isLoading: Bool {
        if case .syncing = manager.syncStatus { return true }
        return false
    }
    var errorMessage: String? {
        get {
            if case .error(let msg) = manager.syncStatus { return msg }
            return nil
        }
        set { if newValue == nil { manager.clearError() } }
    }

    // MARK: - CRUD

    func addShow(_ show: TVShow) {
        manager.save(show: show.inList(manager.selectedList))
        Analytics.logEvent("show_added", parameters: [
            "media_type": show.mediaType,
            "want_to_watch": show.wantToWatch ? "true" : "false",
        ])
        if !show.posterURL.isEmpty { return }
        fetchMissingPosters()
        requestReviewIfAppropriate()
    }

    func deleteShow(_ show: TVShow) {
        manager.delete(show)
        Analytics.logEvent("show_deleted", parameters: [
            "media_type": show.mediaType,
        ])
    }

    func clearAllShows() {
        for show in manager.showsForSelectedList {
            manager.delete(show)
        }
    }

    func updateShow(_ show: TVShow) {
        if let old = manager.shows.first(where: { $0.id == show.id }),
           old.rating != show.rating || old.thumbs != show.thumbs {
            Analytics.logEvent("show_rated", parameters: [
                "rating": show.rating,
                "thumbs": show.thumbs,
            ])
        }
        manager.save(show: show)
    }

    func moveShow(_ show: TVShow, toList list: TVList) {
        Analytics.logEvent("show_moved", parameters: [
            "to_shared_list": list.isOwned ? "false" : "true",
        ])
        Task { await manager.move(show: show, toList: list) }
    }

    func replaceAllShows(with newShows: [TVShow]) {
        for show in manager.showsForSelectedList {
            manager.delete(show)
        }
        for show in newShows.sorted(by: { $0.addedAt > $1.addedAt }) {
            manager.save(show: show.inList(manager.selectedList))
        }
    }

    func appendShows(_ newShows: [TVShow]) {
        let existing = manager.showsForSelectedList
        var addedCount = 0
        for show in newShows {
            let isDuplicate: Bool
            if show.tmdbId > 0 {
                isDuplicate = existing.contains { $0.tmdbId == show.tmdbId }
            } else if show.tvMazeId > 0 {
                isDuplicate = existing.contains { $0.tvMazeId == show.tvMazeId }
            } else {
                isDuplicate = existing.contains { $0.title.lowercased() == show.title.lowercased() }
            }
            if !isDuplicate {
                manager.save(show: show.inList(manager.selectedList))
                addedCount += 1
            }
        }
        if addedCount > 0 {
            Analytics.logEvent("csv_import", parameters: [
                "show_count": addedCount,
            ])
        }
    }

    // MARK: - Poster fetching

    func fetchMissingPosters() {
        Task {
            let targets = manager.shows
                .filter { $0.posterURL.isEmpty }
                .map { (id: $0.id, tvMazeId: $0.tvMazeId, tmdbId: $0.tmdbId, mediaType: $0.mediaType) }
            guard !targets.isEmpty else { return }

            var updates: [(UUID, String)] = []

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
                            guard let request = try? TMDBProxy.request(path: path) else { return nil }
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
                    if let pair = result { updates.append(pair) }
                }
            }

            for (id, url) in updates {
                if var show = manager.shows.first(where: { $0.id == id }) {
                    show.posterURL = url
                    manager.save(show: show)
                }
            }
        }
    }

    // MARK: - Review

    private func requestReviewIfAppropriate() {
        guard manager.shows.count == 3,
              !UserDefaults.standard.bool(forKey: reviewRequestedKey)
        else { return }
        UserDefaults.standard.set(true, forKey: reviewRequestedKey)
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
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
