import Foundation

struct TVShow: Identifiable, Codable {
    var id: UUID
    var title: String
    var network: String     // Channel or streaming service name
    var posterURL: String
    var summary: String
    var genres: [String]
    var rating: Int         // 0 = unrated, 1–5 stars
    var thumbs: String      // "up", "down", or "none"
    var notes: String
    var addedAt: Date
    var tvMazeId: Int       // -1 if entered manually
    var wantToWatch: Bool   // true = on watchlist, false = already seen

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
        wantToWatch: Bool = false
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
    }
}
