import SwiftUI

struct PodcastCard: View {
    let podcast: Podcast
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Top row: artwork + title/author
            HStack(alignment: .top, spacing: AppSpacing.md) {
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
                }

                Spacer()
            }

            // Metadata (full width, below artwork)
            HStack(spacing: AppSpacing.xs) {
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

            // Description (expandable with categories)
            if !podcast.description.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(podcast.description)
                        .font(.smallText)
                        .foregroundStyle(Color.appMutedForeground)
                        .lineLimit(isExpanded ? nil : 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .bottomTrailing) {
                            if !isExpanded {
                                LinearGradient(
                                    colors: [Color.appMutedForeground.opacity(0), Color.appMutedForeground.opacity(0.15)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(height: 20)
                                .allowsHitTesting(false)
                            }
                        }

                    if isExpanded, !podcast.categories.isEmpty {
                        HStack(spacing: AppSpacing.xs) {
                            ForEach(podcast.categories.prefix(3), id: \.self) { category in
                                Text(translateCategory(category))
                                    .font(.caption2Text)
                                    .foregroundStyle(Color.appAccent)
                                    .padding(.horizontal, AppSpacing.sm)
                                    .padding(.vertical, 2)
                                    .background(Color.appAccent.opacity(0.1))
                                    .clipShape(.rect(cornerRadius: AppRadius.sm))
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if UIAccessibility.isReduceMotionEnabled {
                        isExpanded.toggle()
                    } else {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }
                }
                .accessibilityLabel(isExpanded ? "Skjul beskrivelse" : "Vis beskrivelse")
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
