import CloudKit
import Foundation

struct TVShow: Identifiable, Codable {
    var id: UUID
    var title: String
    var network: String
    var posterURL: String
    var summary: String
    var genres: [String]
    var rating: Int         // 0 = unrated, 1–5 stars
    var thumbs: String      // "up", "down", or "none"
    var notes: String
    var addedAt: Date
    var tvMazeId: Int       // -1 if not from TVMaze
    var wantToWatch: Bool
    var mediaType: String   // "tv" or "movie"
    var tmdbId: Int         // -1 if not from TMDB
    var listID: String      // CKRecordZone name
    var listOwnerID: String // CKRecordZone ownerName

    init(
        id: UUID = UUID(),
        title: String,
        network: String,
        posterURL: String,
        summary: String,
        genres: [String],
        rating: Int,
        thumbs: String,
        notes: String,
        addedAt: Date = Date(),
        tvMazeId: Int,
        wantToWatch: Bool = false,
        mediaType: String = "tv",
        tmdbId: Int = -1,
        listID: String = TVList.myShowsID,
        listOwnerID: String = CKCurrentUserDefaultName
    ) {
        self.id = id
        self.title = title
        self.network = network
        self.posterURL = posterURL
        self.summary = summary
        self.genres = genres
        self.rating = rating
        self.thumbs = thumbs
        self.notes = notes
        self.addedAt = addedAt
        self.tvMazeId = tvMazeId
        self.wantToWatch = wantToWatch
        self.mediaType = mediaType
        self.tmdbId = tmdbId
        self.listID = listID
        self.listOwnerID = listOwnerID
    }

    // Custom decoder for backward compat with JSON lacking newer fields
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(UUID.self,     forKey: .id)
        title       = try c.decode(String.self,   forKey: .title)
        network     = try c.decode(String.self,   forKey: .network)
        posterURL   = try c.decode(String.self,   forKey: .posterURL)
        summary     = try c.decode(String.self,   forKey: .summary)
        genres      = try c.decode([String].self, forKey: .genres)
        rating      = try c.decode(Int.self,      forKey: .rating)
        thumbs      = try c.decode(String.self,   forKey: .thumbs)
        notes       = try c.decode(String.self,   forKey: .notes)
        addedAt     = try c.decode(Date.self,     forKey: .addedAt)
        tvMazeId    = try c.decode(Int.self,      forKey: .tvMazeId)
        wantToWatch = try c.decode(Bool.self,     forKey: .wantToWatch)
        mediaType   = (try? c.decode(String.self, forKey: .mediaType))   ?? "tv"
        tmdbId      = (try? c.decode(Int.self,    forKey: .tmdbId))      ?? -1
        listID      = (try? c.decode(String.self, forKey: .listID))      ?? TVList.myShowsID
        listOwnerID = (try? c.decode(String.self, forKey: .listOwnerID)) ?? CKCurrentUserDefaultName
    }

    func inList(_ list: TVList) -> TVShow {
        var copy = self
        copy.listID = list.id
        copy.listOwnerID = list.zoneOwnerName
        return copy
    }
}

// MARK: - CloudKit

extension TVShow {
    static let recordType = "TVShow"

    init?(from record: CKRecord) {
        guard let uuid = UUID(uuidString: record.recordID.recordName),
              let title = record["title"] as? String
        else { return nil }
        id          = uuid
        listID      = record.recordID.zoneID.zoneName
        listOwnerID = record.recordID.zoneID.ownerName
        self.title  = title
        network     = record["network"]   as? String ?? ""
        posterURL   = record["posterURL"] as? String ?? ""
        summary     = record["summary"]   as? String ?? ""
        genres      = record["genres"]    as? [String] ?? []
        rating      = (record["rating"]   as? NSNumber)?.intValue ?? 0
        thumbs      = record["thumbs"]    as? String ?? "none"
        notes       = record["notes"]     as? String ?? ""
        addedAt     = record["addedAt"] as? Date ?? record.creationDate ?? Date()
        tvMazeId    = (record["tvMazeId"] as? NSNumber)?.intValue ?? -1
        wantToWatch = (record["wantToWatch"] as? NSNumber)?.boolValue ?? false
        mediaType   = record["mediaType"] as? String ?? "tv"
        tmdbId      = (record["tmdbId"]   as? NSNumber)?.intValue ?? -1
    }

    func toCKRecord() -> CKRecord {
        let zoneID = CKRecordZone.ID(zoneName: listID, ownerName: listOwnerID)
        let record = CKRecord(recordType: TVShow.recordType,
                              recordID: CKRecord.ID(recordName: id.uuidString, zoneID: zoneID))
        record["title"]       = title       as NSString
        record["network"]     = network     as NSString
        record["posterURL"]   = posterURL   as NSString
        record["summary"]     = summary     as NSString
        record["genres"]      = genres      as NSArray
        record["rating"]      = NSNumber(value: rating)
        record["thumbs"]      = thumbs      as NSString
        record["notes"]       = notes       as NSString
        record["addedAt"]     = addedAt     as NSDate
        record["tvMazeId"]    = NSNumber(value: tvMazeId)
        record["wantToWatch"] = NSNumber(value: wantToWatch)
        record["mediaType"]   = mediaType   as NSString
        record["tmdbId"]      = NSNumber(value: tmdbId)
        return record
    }
}
