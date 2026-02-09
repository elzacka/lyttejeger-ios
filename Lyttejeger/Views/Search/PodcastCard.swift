import SwiftUI

struct PodcastCard: View {
    let podcast: Podcast

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            // Artwork
            CachedAsyncImage(url: podcast.imageUrl, size: AppSize.artworkSmall)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(podcast.title)
                    .font(.cardTitle)
                    .foregroundStyle(Color.appForeground)
                    .lineLimit(2)

                Text(podcast.author)
                    .font(.smallText)
                    .foregroundStyle(Color.appMutedForeground)
                    .lineLimit(1)

                HStack(spacing: AppSpacing.xs) {
                    // Category badges
                    ForEach(podcast.categories.prefix(2), id: \.self) { category in
                        Text(translateCategory(category))
                            .font(.caption2Text)
                            .foregroundStyle(Color.appAccent)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, 2)
                            .background(Color.appAccent.opacity(0.1))
                            .clipShape(.rect(cornerRadius: AppRadius.sm))
                    }

                    if podcast.episodeCount > 0 {
                        Text("\(podcast.episodeCount) ep.")
                            .font(.caption2Text)
                            .foregroundStyle(Color.appMutedForeground)
                    }
                }
            }

            Spacer()
        }
        .padding(AppSpacing.md)
        .background(Color.appCard)
        .clipShape(.rect(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(Color.appBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(podcast.title), av \(podcast.author), \(podcast.episodeCount) episoder")
    }
}

#if DEBUG
#Preview {
    PodcastCard(podcast: .preview)
        .padding()
        .background(Color.appBackground)
}
#endif
