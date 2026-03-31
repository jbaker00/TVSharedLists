import Foundation

/// Persists the TV show list as JSON in the app's Documents directory.
class TVShowStore {

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("tvshows.json")
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = .prettyPrinted
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func load() -> [TVShow] {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let shows = try? decoder.decode([TVShow].self, from: data)
        else {
            return []
        }
        return shows
    }

    func save(_ shows: [TVShow]) {
        guard let data = try? encoder.encode(shows) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
