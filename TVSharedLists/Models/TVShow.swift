import Foundation

struct TVShow: Identifiable, Codable {
    var id: UUID
    var title: String
    var network: String     // Channel, streaming service, or "Movie"
    var posterURL: String
    var summary: String
    var genres: [String]
    var rating: Int         // 0 = unrated, 1–5 stars
    var thumbs: String      // "up", "down", or "none"
    var notes: String
    var addedAt: Date
    var tvMazeId: Int       // -1 if not from TVMaze
    var wantToWatch: Bool   // true = on watchlist, false = already seen
    var mediaType: String   // "tv" or "movie"
    var tmdbId: Int         // -1 if not from TMDB

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
        tmdbId: Int = -1
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
    }

    // Custom decoder for backward compat with existing JSON lacking mediaType/tmdbId
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
        mediaType   = (try? c.decode(String.self, forKey: .mediaType)) ?? "tv"
        tmdbId      = (try? c.decode(Int.self,    forKey: .tmdbId))    ?? -1
    }
}
