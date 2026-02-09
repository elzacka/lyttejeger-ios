import SwiftUI

struct QueueView: View {
    @Environment(QueueViewModel.self) private var queueVM
    @Environment(AudioPlayerViewModel.self) private var playerVM
    @State private var showClearConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            if !queueVM.items.isEmpty {
                HStack {
                    Spacer()
                    Button("Tøm") {
                        showClearConfirmation = true
                    }
                    .font(.buttonText)
                    .foregroundStyle(Color.appError)
                    .frame(minHeight: AppSize.touchTarget)
                }
                .padding(.horizontal, AppSpacing.lg)
            }

            if queueVM.items.isEmpty {
                Spacer()

                VStack(spacing: AppSpacing.lg) {
                    Image("LaunchLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .opacity(0.4)

                    Text("Ingen episoder i køen")
                        .font(.bodyText)
                        .foregroundStyle(Color.appMutedForeground)
                }

                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(queueVM.items, id: \.episodeId) { item in
                            QueueItemCard(item: item)
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, 100)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Tøm køen?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("Tøm kø (\(queueVM.items.count))", role: .destructive) {
                queueVM.clearQueue()
            }
        } message: {
            Text("Alle \(queueVM.items.count) episoder i køen vil bli fjernet.")
        }
    }
}

// MARK: - Queue Item Card

private struct QueueItemCard: View {
    let item: QueueItem

    @Environment(AudioPlayerViewModel.self) private var playerVM
    @Environment(PlaybackProgressViewModel.self) private var progressVM
    @Environment(QueueViewModel.self) private var queueVM

    private var episode: Episode { item.toEpisode() }

    private var isNowPlaying: Bool {
        playerVM.currentEpisode?.id == item.episodeId
    }

    private var metadataLine: String {
        var parts: [String] = []
        if let published = item.publishedAt, !published.isEmpty {
            parts.append(formatRelativeDate(published))
        }
        if let dur = item.duration, dur > 0 {
            parts.append(formatDuration(dur))
        }
        return parts.joined(separator: " · ")
    }

    private var hasBadges: Bool {
        progressVM.isCompleted(item.episodeId)
            || (progressVM.progressFraction(for: item.episodeId) ?? 0) > 0.01
            || item.chaptersUrl != nil
            || item.transcriptUrl != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                CachedAsyncImage(url: item.imageUrl ?? item.podcastImage, size: AppSize.artworkSmall)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    if let season = item.season, let ep = item.episode, FeatureFlags.seasonEpisodeMetadata {
                        Text("S\(season) E\(ep)")
                            .font(.caption2Text)
                            .foregroundStyle(Color.appAccent)
                    }

                    Text(item.title)
                        .font(.cardTitle)
                        .foregroundStyle(isNowPlaying ? Color.appAccent : Color.appForeground)
                        .lineLimit(2)

                    if !metadataLine.isEmpty {
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
                    }

                    // Badges
                    if hasBadges {
                        HStack(spacing: AppSpacing.sm) {
                            if progressVM.isCompleted(item.episodeId) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.appSuccess)
                                    .accessibilityLabel("Hørt")
                            } else if let fraction = progressVM.progressFraction(for: item.episodeId), fraction > 0.01 {
                                Text("\(Int(fraction * 100))%")
                                    .font(.caption2Text)
                                    .foregroundStyle(Color.appAccent)
                            }

                            if item.chaptersUrl != nil {
                                Image(systemName: "list.number")
                                    .font(.caption2)
                                    .foregroundStyle(Color.appAccent)
                                    .accessibilityLabel("Kapitler")
                            }

                            if item.transcriptUrl != nil {
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
                    playerVM.play(episode: episode, podcastTitle: item.podcastTitle, podcastImage: item.podcastImage)
                    queueVM.remove(item)
                } label: {
                    Image(systemName: isNowPlaying && playerVM.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.appAccent)
                }
                .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                .accessibilityLabel(isNowPlaying && playerVM.isPlaying ? "Pause" : "Spill \(item.title)")
            }

            // Progress bar
            if let fraction = progressVM.progressFraction(for: item.episodeId), fraction > 0.01, !progressVM.isCompleted(item.episodeId) {
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
            if let desc = item.episodeDescription, !desc.isEmpty {
                ExpandableText(text: desc)
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
        .contextMenu {
            Button {
                playerVM.play(episode: episode, podcastTitle: item.podcastTitle, podcastImage: item.podcastImage)
                queueVM.remove(item)
            } label: {
                Label("Spill", systemImage: "play.fill")
            }
            if let index = queueVM.items.firstIndex(where: { $0.episodeId == item.episodeId }), index > 0 {
                Button {
                    queueVM.move(from: IndexSet(integer: index), to: index - 1)
                } label: {
                    Label("Flytt opp", systemImage: "arrow.up")
                }
            }
            if let index = queueVM.items.firstIndex(where: { $0.episodeId == item.episodeId }), index < queueVM.items.count - 1 {
                Button {
                    queueVM.move(from: IndexSet(integer: index), to: index + 2)
                } label: {
                    Label("Flytt ned", systemImage: "arrow.down")
                }
            }
            Button(role: .destructive) {
                queueVM.remove(item)
            } label: {
                Label("Fjern fra kø", systemImage: "trash")
            }
        }
    }
}

#if DEBUG
#Preview("Med episoder") {
    PreviewWrapper(seeded: true) {
        NavigationStack {
            QueueView()
        }
    }
}

#Preview("Tom kø") {
    PreviewWrapper {
        NavigationStack {
            QueueView()
        }
    }
}
#endif
