import Foundation

/// Persists the TV show list as JSON.
///
/// Storage priority:
///   1. iCloud ubiquitous container (Documents/tvshows.json) — survives uninstall/device change.
///   2. Local Documents directory — fallback when iCloud is unavailable (e.g. simulator, no Apple ID).
///
/// On first launch after adding iCloud support, any existing local data is automatically
/// migrated to the iCloud container and the local copy is removed.
///
/// NOTE: `url(forUbiquityContainerIdentifier:)` may briefly block on first call. It is called
/// synchronously here during app launch for simplicity; the delay is imperceptible in practice.
class TVShowStore {

    private static let fileName = "tvshows.json"

    private let fileURL: URL
    private let isUsingiCloud: Bool

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

    init() {
        let fm = FileManager.default
        if let container = fm.url(forUbiquityContainerIdentifier: nil) {
            let docsDir = container.appendingPathComponent("Documents", isDirectory: true)
            try? fm.createDirectory(at: docsDir, withIntermediateDirectories: true, attributes: nil)
            fileURL = docsDir.appendingPathComponent(TVShowStore.fileName)
            isUsingiCloud = true
        } else {
            fileURL = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(TVShowStore.fileName)
            isUsingiCloud = false
        }
    }

    func load() -> [TVShow] {
        // Try the primary store (iCloud or local).
        if let shows = decode(from: fileURL) {
            return shows
        }

        // iCloud store is empty/missing — check for a local file to migrate.
        if isUsingiCloud {
            let localURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(TVShowStore.fileName)
            if let shows = decode(from: localURL) {
                if !shows.isEmpty {
                    save(shows)                                    // copy to iCloud
                    try? FileManager.default.removeItem(at: localURL)  // clean up local copy
                }
                return shows
            }
        }

        return []
    }

    func save(_ shows: [TVShow]) {
        guard let data = try? encoder.encode(shows) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Private

    private func decode(from url: URL) -> [TVShow]? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let shows = try? decoder.decode([TVShow].self, from: data)
        else { return nil }
        return shows
    }
}
