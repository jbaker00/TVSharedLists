import SwiftUI

// Interactive star rating picker
struct StarRatingView: View {
    @Binding var rating: Int
    var starSize: CGFloat = 32
    var spacing: CGFloat = 8

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: starSize, weight: .medium))
                    .foregroundStyle(star <= rating ? Color.yellow : Color.secondary.opacity(0.35))
                    .onTapGesture {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                            rating = (star == rating) ? 0 : star
                        }
                    }
                    .scaleEffect(star <= rating ? 1.05 : 1.0)
                    .animation(.spring(response: 0.2), value: rating)
            }
        }
    }
}

// Display-only (read-only) star row
struct StarRatingDisplayView: View {
    let rating: Int
    var starSize: CGFloat = 13
    var spacing: CGFloat = 2

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: starSize, weight: .medium))
                    .foregroundStyle(star <= rating ? Color.yellow : Color.secondary.opacity(0.25))
            }
        }
    }
}

private struct StarRatingPreview: View {
    @State private var rating = 3
    var body: some View {
        VStack(spacing: 20) {
            StarRatingView(rating: $rating)
            StarRatingDisplayView(rating: 4)
            StarRatingDisplayView(rating: 2, starSize: 18)
        }
        .padding()
    }
}

#Preview {
    StarRatingPreview()
}
