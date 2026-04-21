import Foundation

// MARK: - Unified search result (TVMaze + TMDB)

struct MediaSearchResult: Identifiable {
    enum Source { case tvMaze, tmdbTV, tmdbMovie }

    let id: String
    let displayTitle: String
    let network: String
    let posterURL: String
    let summary: String
    let genres: [String]
    let status: String?
    let mediaType: String   // "tv" or "movie"
    let tvMazeId: Int
    let tmdbId: Int
    let source: Source
}

extension TVMazeShow {
    var asMediaResult: MediaSearchResult {
        MediaSearchResult(
            id: "tvmaze-\(id)",
            displayTitle: name,
            network: networkName,
            posterURL: posterURL,
            summary: cleanSummary,
            genres: genres,
            status: status,
            mediaType: "tv",
            tvMazeId: id,
            tmdbId: -1,
            source: .tvMaze
        )
    }
}

// MARK: - TMDB API response models (private)

private struct TMDBSearchResponse<T: Decodable>: Decodable {
    let results: [T]
}

/// Used for /search/multi — each item carries a media_type field ("movie", "tv", or "person")
private struct TMDBMultiItem: Decodable {
    let id: Int
    let mediaType: String    // "movie", "tv", or "person"
    let title: String?       // movies
    let name: String?        // TV shows
    let overview: String?
    let posterPath: String?
    let genreIds: [Int]?
    let releaseDate: String?    // movies
    let firstAirDate: String?   // TV shows

    enum CodingKeys: String, CodingKey {
        case id, title, name, overview
        case mediaType    = "media_type"
        case posterPath   = "poster_path"
        case genreIds     = "genre_ids"
        case releaseDate  = "release_date"
        case firstAirDate = "first_air_date"
    }

    func asMediaResult() -> MediaSearchResult? {
        let isMovie = mediaType == "movie"
        guard isMovie || mediaType == "tv" else { return nil }   // skip "person"

        let rawTitle = isMovie ? (title ?? "") : (name ?? "")
        let year: String?
        if isMovie {
            year = releaseDate.flatMap { $0.count >= 4 ? String($0.prefix(4)) : nil }
        } else {
            year = nil
        }
        let displayTitle = (isMovie && year != nil) ? "\(rawTitle) (\(year!))" : rawTitle

        let genreMap = isMovie ? TMDBGenres.movie : TMDBGenres.tv

        return MediaSearchResult(
            id: "tmdb-\(mediaType)-\(id)",
            displayTitle: displayTitle,
            network: isMovie ? "Movie" : "",
            posterURL: posterPath.map { "https://image.tmdb.org/t/p/w342\($0)" } ?? "",
            summary: overview ?? "",
            genres: (genreIds ?? []).compactMap { genreMap[$0] },
            status: nil,
            mediaType: isMovie ? "movie" : "tv",
            tvMazeId: -1,
            tmdbId: id,
            source: isMovie ? .tmdbMovie : .tmdbTV
        )
    }
}

// MARK: - Genre ID lookup tables

private enum TMDBGenres {
    static let movie: [Int: String] = [
        28: "Action", 12: "Adventure", 16: "Animation", 35: "Comedy", 80: "Crime",
        99: "Documentary", 18: "Drama", 10751: "Family", 14: "Fantasy", 36: "History",
        27: "Horror", 10402: "Music", 9648: "Mystery", 10749: "Romance",
        878: "Science Fiction", 53: "Thriller", 10752: "War", 37: "Western"
    ]
    static let tv: [Int: String] = [
        10759: "Action & Adventure", 16: "Animation", 35: "Comedy", 80: "Crime",
        99: "Documentary", 18: "Drama", 10751: "Family", 10762: "Kids",
        9648: "Mystery", 10763: "News", 10764: "Reality", 10765: "Sci-Fi & Fantasy",
        10766: "Soap", 10767: "Talk", 10768: "War & Politics", 37: "Western"
    ]
}

// MARK: - Service

@MainActor
class TMDBService: ObservableObject {
    @Published var multiResults: [MediaSearchResult] = []
    @Published var isSearching = false

    private var searchTask: Task<Void, Never>?

    // MARK: - Multi-search (debounced — movies + TV in one call)

    func searchMulti(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { multiResults = []; return }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await fetchMulti(query: trimmed)
        }
    }

    // MARK: - Clear

    func clear() {
        searchTask?.cancel()
        multiResults = []
        isSearching = false
    }

    // MARK: - Private fetch

    private func fetchMulti(query: String) async {
        isSearching = true
        defer { isSearching = false }

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://api.themoviedb.org/3/search/multi?query=\(encoded)&page=1") else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(TMDBSecrets.readAccessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let resp = try JSONDecoder().decode(TMDBSearchResponse<TMDBMultiItem>.self, from: data)
            multiResults = Array(resp.results.compactMap { $0.asMediaResult() }.prefix(10))
        } catch {
            // Leave existing results unchanged on error
        }
    }
}
