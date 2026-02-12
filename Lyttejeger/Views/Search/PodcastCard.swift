import SwiftUI

struct PodcastCard: View {
    let podcast: Podcast

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                // Artwork → navigates to podcast page
                NavigationLink(value: PodcastRoute(podcast: podcast)) {
                    CachedAsyncImage(url: podcast.imageUrl, size: AppSize.artworkSmall)
                }
                .buttonStyle(CardButtonStyle())

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(podcast.title)
                        .font(.cardTitle)
                        .foregroundStyle(Color.appForeground)

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

                        if podcast.explicit {
                            Text("E")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.appMutedForeground)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.appBorder.opacity(0.4))
                                .clipShape(.rect(cornerRadius: 3))
                                .accessibilityLabel("Eksplisitt innhold")
                        }

                        if let date = formatShortDate(podcast.lastUpdated) {
                            Text(date)
                                .font(.caption2Text)
                                .foregroundStyle(Color.appMutedForeground)
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

            // Description
            if !podcast.description.isEmpty {
                ExpandableText(text: podcast.description, previewLines: 1)
                    .padding(.top, AppSpacing.sm)
            }
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
