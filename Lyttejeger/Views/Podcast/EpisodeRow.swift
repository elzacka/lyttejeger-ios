import SwiftUI

struct EpisodeRow: View {
    let episode: Episode
    let podcastTitle: String
    let podcastImage: String

    @Environment(AudioPlayerViewModel.self) private var playerVM
    @Environment(PlaybackProgressViewModel.self) private var progressVM
    @State private var isExpanded = false

    private var isNowPlaying: Bool {
        playerVM.currentEpisode?.id == episode.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    if let season = episode.season, let ep = episode.episode, FeatureFlags.seasonEpisodeMetadata {
                        Text("S\(season) E\(ep)")
                            .font(.caption2Text)
                            .foregroundStyle(Color.appAccent)
                    }

                    Text(episode.title)
                        .font(.cardTitle)
                        .foregroundStyle(isNowPlaying ? Color.appAccent : Color.appForeground)
                        .lineLimit(2)

                    // Row 1: core info
                    HStack(spacing: AppSpacing.sm) {
                        if isNowPlaying {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.appAccent)
                        }

                        Text(formatRelativeDate(episode.publishedAt))
                            .font(.caption2Text)
                            .foregroundStyle(Color.appMutedForeground)

                        if episode.duration > 0 {
                            Text(formatDuration(episode.duration))
                                .font(.caption2Text)
                                .foregroundStyle(Color.appMutedForeground)
                        }
                    }

                    // Row 2: badges (progress, chapters, transcript)
                    if progressVM.isCompleted(episode.id)
                        || (progressVM.progressFraction(for: episode.id) ?? 0) > 0.01
                        || episode.chaptersUrl != nil
                        || episode.transcriptUrl != nil {
                        HStack(spacing: AppSpacing.sm) {
                            if progressVM.isCompleted(episode.id) {
                                HStack(spacing: 2) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10))
                                    Text("Hørt")
                                        .font(.caption2Text)
                                }
                                .foregroundStyle(Color.appSuccess)
                            } else if let fraction = progressVM.progressFraction(for: episode.id), fraction > 0.01 {
                                Text("\(Int(fraction * 100))%")
                                    .font(.caption2Text)
                                    .foregroundStyle(Color.appAccent)
                            }

                            if episode.chaptersUrl != nil {
                                HStack(spacing: 2) {
                                    Image(systemName: "list.number")
                                        .font(.caption2)
                                    Text("Kapitler")
                                        .font(.caption2Text)
                                }
                                .foregroundStyle(Color.appAccent)
                            }

                            if episode.transcriptUrl != nil {
                                HStack(spacing: 2) {
                                    Image(systemName: "text.quote")
                                        .font(.caption2)
                                    Text("Tekst")
                                        .font(.caption2Text)
                                }
                                .foregroundStyle(Color.appAccent)
                            }
                        }
                    }
                }

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    playerVM.play(episode: episode, podcastTitle: podcastTitle, podcastImage: podcastImage)
                } label: {
                    Image(systemName: isNowPlaying && playerVM.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 32))
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

            // Description — tap to expand/collapse
            if !episode.description.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(episode.description)
                        .font(.smallText)
                        .foregroundStyle(Color.appMutedForeground)
                        .lineLimit(isExpanded ? nil : 2)

                    Text(isExpanded ? "Vis mindre" : "Vis mer")
                        .font(.caption2Text)
                        .foregroundStyle(Color.appAccent)
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
                .accessibilityHint(isExpanded ? "Trykk for å skjule beskrivelse" : "Trykk for å vise hele beskrivelsen")
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
        EpisodeRow(
            episode: .preview,
            podcastTitle: "Aftenpodden",
            podcastImage: ""
        )
        .padding()
    }
}

#Preview("Spilles nå") {
    PreviewWrapper(player: .playing) {
        EpisodeRow(
            episode: .preview,
            podcastTitle: "Aftenpodden",
            podcastImage: ""
        )
        .padding()
    }
}
#endif
