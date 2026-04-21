import Foundation
import UniformTypeIdentifiers

// MARK: - Custom UTType

extension UTType {
    /// The UTType for `.tvlist` files — a JSON-encoded array of TVShow objects.
    /// Declared in Info.plist under UTExportedTypeDeclarations.
    static let tvList = UTType(exportedAs: "com.jamesbaker.tvsharedlists.tvlist")
}

// MARK: - Encode / Decode helpers

enum TVListService {

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = .prettyPrinted
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// Encodes a list of shows to `.tvlist` data. Returns nil on failure.
    static func encode(_ shows: [TVShow]) -> Data? {
        try? encoder.encode(shows)
    }

    /// Decodes a list of shows from `.tvlist` data. Returns nil on failure.
    static func decode(from data: Data) -> [TVShow]? {
        try? decoder.decode([TVShow].self, from: data)
    }
}
