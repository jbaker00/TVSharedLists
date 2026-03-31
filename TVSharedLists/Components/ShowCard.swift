import SwiftUI

struct ShowCard: View {
    let show: TVShow

    private var thumbsDisplay: (icon: String, color: Color)? {
        switch show.thumbs {
        case "up":   return ("hand.thumbsup.fill",   .green)
        case "down": return ("hand.thumbsdown.fill", .red)
        default:     return nil
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            PosterImageView(url: show.posterURL, width: 68, height: 102)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(show.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if show.wantToWatch {
                        Image(systemName: "bookmark.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                if !show.network.isEmpty, show.network != "Unknown" {
                    Label(show.network, systemImage: "tv.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !show.genres.isEmpty {
                    Text(show.genres.prefix(3).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                if show.wantToWatch {
                    Text("Want to Watch")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.orange.opacity(0.12)))
                } else if !show.notes.isEmpty {
                    Text(show.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .italic()
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    if show.rating > 0 {
                        StarRatingDisplayView(rating: show.rating)
                    }
                    Spacer()
                    if let thumbs = thumbsDisplay {
                        Image(systemName: thumbs.icon)
                            .foregroundStyle(thumbs.color)
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(show.wantToWatch ? Color.orange.opacity(0.35) : Color.clear, lineWidth: 1)
                )
        )
    }
}

// MARK: - Poster image with placeholder

struct PosterImageView: View {
    let url: String
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Group {
            if let imageURL = URL(string: url), !url.isEmpty {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(
                LinearGradient(
                    colors: [Color.indigo.opacity(0.3), Color.purple.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "tv")
                    .font(.system(size: width * 0.32))
                    .foregroundStyle(.white.opacity(0.5))
            )
    }
}
