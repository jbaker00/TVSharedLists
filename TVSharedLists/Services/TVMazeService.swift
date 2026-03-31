import Foundation

// MARK: - TVMaze API response models

struct TVMazeShow: Codable, Identifiable {
    let id: Int
    let name: String
    let network: TVMazeNetwork?
    let webChannel: TVMazeWebChannel?
    let summary: String?
    let image: TVMazeImage?
    let genres: [String]
    let status: String?

    var networkName: String {
        network?.name ?? webChannel?.name ?? "Unknown"
    }

    var posterURL: String {
        let url = image?.medium ?? image?.original ?? ""
        return url.replacingOccurrences(of: "http://", with: "https://")
    }

    var cleanSummary: String {
        guard let summary else { return "" }
        return summary
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct TVMazeNetwork: Codable {
    let name: String
}

struct TVMazeWebChannel: Codable {
    let name: String
}

struct TVMazeImage: Codable {
    let medium: String?
    let original: String?
}

struct TVMazeSearchResult: Codable {
    let score: Double
    let show: TVMazeShow
}

// MARK: - Service

@MainActor
class TVMazeService: ObservableObject {
    @Published var searchResults: [TVMazeShow] = []
    @Published var isSearching = false

    private var searchTask: Task<Void, Never>?

    func search(query: String) {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }

            isSearching = true

            let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            guard let url = URL(string: "https://api.tvmaze.com/search/shows?q=\(encoded)") else {
                isSearching = false
                return
            }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let results = try JSONDecoder().decode([TVMazeSearchResult].self, from: data)
                searchResults = Array(results.map(\.show).prefix(10))
            } catch {
                // On error, leave existing results unchanged
            }

            isSearching = false
        }
    }

    func clear() {
        searchTask?.cancel()
        searchResults = []
        isSearching = false
    }
}
