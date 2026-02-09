import SwiftUI

struct EpisodeCard: View {
    let episode: Episode
    let podcastTitle: String
    let podcastImage: String

    @Environment(AudioPlayerViewModel.self) private var playerVM
    @Environment(PlaybackProgressViewModel.self) private var progressVM

    private var isNowPlaying: Bool {
        playerVM.currentEpisode?.id == episode.id
    }

    private var metadataLine: String {
        var parts: [String] = []
        parts.append(formatRelativeDate(episode.publishedAt))
        if episode.duration > 0 {
            parts.append(formatDuration(episode.duration))
        }
        return parts.joined(separator: " · ")
    }

    private var hasBadges: Bool {
        progressVM.isCompleted(episode.id)
            || (progressVM.progressFraction(for: episode.id) ?? 0) > 0.01
            || episode.chaptersUrl != nil
            || episode.transcriptUrl != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                CachedAsyncImage(url: episode.imageUrl ?? podcastImage, size: AppSize.artworkSmall)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    if let season = episode.season, let ep = episode.episode {
                        Text("S\(season) E\(ep)")
                            .font(.caption2Text)
                            .foregroundStyle(Color.appAccent)
                    }

                    Text(episode.title)
                        .font(.cardTitle)
                        .foregroundStyle(isNowPlaying ? Color.appAccent : Color.appForeground)
                        .lineLimit(2)

                    HStack(spacing: AppSpacing.sm) {
                        if isNowPlaying {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.appAccent)
                        }

                        Text(metadataLine)
                            .font(.caption2Text)
                            .foregroundStyle(Color.appMutedForeground)
                            .lineLimit(1)
                    }

                    // Badges
                    if hasBadges {
                        HStack(spacing: AppSpacing.sm) {
                            if progressVM.isCompleted(episode.id) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.appSuccess)
                                    .accessibilityLabel("Hørt")
                            } else if let fraction = progressVM.progressFraction(for: episode.id), fraction > 0.01 {
                                Text("\(Int(fraction * 100))%")
                                    .font(.caption2Text)
                                    .foregroundStyle(Color.appAccent)
                            }

                            if episode.chaptersUrl != nil {
                                Image(systemName: "list.number")
                                    .font(.caption2)
                                    .foregroundStyle(Color.appAccent)
                                    .accessibilityLabel("Kapitler")
                            }

                            if episode.transcriptUrl != nil {
                                Image(systemName: "text.quote")
                                    .font(.caption2)
                                    .foregroundStyle(Color.appAccent)
                                    .accessibilityLabel("Tekst")
                            }
                        }
                    }
                }

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    playerVM.play(episode: episode, podcastTitle: podcastTitle, podcastImage: podcastImage)
                } label: {
                    Image(systemName: isNowPlaying && playerVM.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.appAccent)
                }
                .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                .accessibilityLabel(isNowPlaying && playerVM.isPlaying ? "Pause" : "Spill \(episode.title)")
            }

            // Progress bar
            if let fraction = progressVM.progressFraction(for: episode.id), fraction > 0.01, !progressVM.isCompleted(episode.id) {
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.appAccent)
                        .frame(width: geo.size.width * fraction)
                }
                .frame(height: 3)
                .background(Color.appBorder)
                .clipShape(.rect(cornerRadius: 1.5))
            }

            // Description — collapsed by default
            if !episode.description.isEmpty {
                ExpandableText(text: episode.description)
            }
        }
        .padding(AppSpacing.md)
        .background(isNowPlaying ? Color.appAccent.opacity(0.08) : Color.appCard)
        .clipShape(.rect(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(isNowPlaying ? Color.appAccent.opacity(0.4) : Color.appBorder, lineWidth: isNowPlaying ? 1.5 : 1)
        )
        .animation(UIAccessibility.isReduceMotionEnabled ? nil : .easeOut(duration: 0.2), value: isNowPlaying)
        .episodeContextMenu(episode: episode, podcastTitle: podcastTitle, podcastImage: podcastImage)
    }
}

#if DEBUG
#Preview("Standard") {
    PreviewWrapper {
        EpisodeCard(
            episode: .preview,
            podcastTitle: "Aftenpodden",
            podcastImage: ""
        )
        .padding()
    }
}

#Preview("Spilles nå") {
    PreviewWrapper(player: .playing) {
        EpisodeCard(
            episode: .preview,
            podcastTitle: "Aftenpodden",
            podcastImage: ""
        )
        .padding()
    }
}
#endif
