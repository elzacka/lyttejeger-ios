import SwiftUI

struct EpisodeCard: View {
    let episode: Episode
    let podcastTitle: String
    let podcastImage: String
    var showArtwork: Bool = true
    /// Only the podcast screen shows descriptions. It is where a listener picks
    /// between episodes of a show they already chose, and it is the only screen
    /// that renders the description at all — the player does not.
    var showDescription: Bool = false
    var onPlay: (() -> Void)? = nil
    var useDefaultContextMenu: Bool = true
    /// Replaces the standard menu content. Queue rows pass their own actions
    /// so they do not need a context menu, which would collide with the
    /// long-press reorder drag.
    var menuContent: (() -> AnyView)? = nil

    @Environment(AudioPlayerViewModel.self) private var playerVM
    @Environment(PlaybackProgressViewModel.self) private var progressVM
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Diameter of the play overlay on the artwork. Well inside the 56pt
    /// artwork, which is itself the touch target.
    private static let playOverlaySize: CGFloat = 28

    private var isNowPlaying: Bool {
        playerVM.currentEpisode?.id == episode.id
    }

    private var isPlayingNow: Bool {
        isNowPlaying && playerVM.isPlaying
    }

    /// Two lines is enough for the useful part of almost every title. Feeds
    /// routinely put a whole topic list in the title field, and letting those
    /// wrap freely turned one row into half a screen.
    private var titleLineLimit: Int {
        dynamicTypeSize.isAccessibilitySize ? 4 : 2
    }

    private var metadataLine: String {
        var parts: [String] = []
        if !episode.publishedAt.isEmpty {
            parts.append(formatRelativeDate(episode.publishedAt))
        }
        if episode.duration > 0 {
            parts.append(formatDuration(episode.duration))
        }
        return parts.joined(separator: " · ")
    }

    private var podcastRoute: PodcastRoute {
        PodcastRoute(
            podcast: .minimal(id: episode.podcastId, title: podcastTitle, imageUrl: podcastImage),
            focusEpisodeId: episode.id
        )
    }

    var body: some View {
        let progress = progressVM.progressInfo(for: episode.id)
        let hasBadges = progress.completed
            || (progress.fraction ?? 0) > 0.01
            || episode.chaptersUrl != nil
            || episode.transcriptUrl != nil
        let card = cardContent(progress: progress, hasBadges: hasBadges)
            .padding(AppSpacing.md)
            .background(isNowPlaying ? Color.appAccent.opacity(0.08) : Color.appCard)
            .clipShape(.rect(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(isNowPlaying ? Color.appAccent.opacity(0.4) : Color.appBorder, lineWidth: isNowPlaying ? 1.5 : 1)
            )
            .animation(UIAccessibility.isReduceMotionEnabled ? nil : .easeOut(duration: 0.2), value: isNowPlaying)
            .accessibilityElement(children: .contain)

        if useDefaultContextMenu {
            card.episodeContextMenu(episode: episode, podcastTitle: podcastTitle, podcastImage: podcastImage)
        } else {
            card
        }
    }

    private func cardContent(progress: PlaybackProgressViewModel.ProgressInfo, hasBadges: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // One row: artwork, text, menu. At accessibility sizes the menu
            // moves below the text, which otherwise gets squeezed into a
            // column a couple of characters wide.
            // Spacing is 0 and applied per gap instead: the artwork needs air
            // from the text, but the controls carry their own — each glyph is
            // centred in a 44pt box, so a spacer before them only narrows the
            // title for no visual gain.
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.sm))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 0))

            layout {
                if showArtwork {
                    artworkPlayButton
                        .padding(.trailing, AppSpacing.md)

                    // With artwork present the row belongs to another podcast
                    // than the one on screen, so the text opens it. The
                    // podcast screen passes showArtwork: false and has no
                    // second podcast to navigate to.
                    NavigationLink(value: podcastRoute) {
                        textColumn(progress: progress, hasBadges: hasBadges)
                    }
                    .buttonStyle(CardButtonStyle())
                    .accessibilityHint("Åpne podkasten")
                } else {
                    textColumn(progress: progress, hasBadges: hasBadges)
                }

                controlsRow
            }

            // Progress bar (always full width)
            if let fraction = progress.fraction, fraction > 0.01, !progress.completed {
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.appAccent)
                        .frame(width: geo.size.width * fraction)
                }
                .frame(height: 3)
                .background(Color.appBorder)
                .clipShape(.rect(cornerRadius: 1.5))
            }

            // Two preview lines, not one: ExpandableText reserves a 44pt tap
            // target regardless, so the second line is free height. The fade
            // has to match the tinted now-playing background, or it draws a
            // white smear across the last line. That background is a
            // translucent accent with the page showing through, not the card
            // colour, so the mix starts from appBackground.
            if showDescription, !episode.description.isEmpty {
                ExpandableText(
                    text: episode.description,
                    backgroundColor: isNowPlaying ? Color.appBackground.mix(with: .appAccent, by: 0.08, in: .device) : .appCard,
                    previewLines: 2
                )
            }
        }
    }

    private func textColumn(progress: PlaybackProgressViewModel.ProgressInfo, hasBadges: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if let season = episode.season, let ep = episode.episode {
                Text("S\(season) E\(ep)")
                    .font(.caption2Text)
                    .foregroundStyle(Color.appAccent)
            }

            Text(episode.title)
                .font(.cardTitle)
                .foregroundStyle(isNowPlaying ? Color.appAccent : Color.appForeground)
                .lineLimit(titleLineLimit)
                .multilineTextAlignment(.leading)

            metaRow(progress: progress, hasBadges: hasBadges)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// The artwork is the play control. It frees the ~52pt the play button
    /// used to take from the title column, and 56pt clears the 44pt minimum
    /// on its own. The overlay is opaque rather than a scrim so contrast does
    /// not depend on the artwork behind it.
    private var artworkPlayButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if isNowPlaying {
                playerVM.togglePlayPause()
            } else if let onPlay {
                onPlay()
            } else {
                playerVM.play(episode: episode, podcastTitle: podcastTitle, podcastImage: podcastImage)
            }
        } label: {
            CachedAsyncImage(
                url: episode.imageUrl.flatMap { $0.isEmpty ? nil : $0 } ?? podcastImage,
                size: AppSize.artworkSmall
            )
            .overlay {
                ZStack {
                    Circle()
                        .fill(Color.appAccent)
                        .frame(width: Self.playOverlaySize, height: Self.playOverlaySize)

                    Image(systemName: isPlayingNow ? "pause.fill" : "play.fill")
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(CardButtonStyle())
        .accessibilityLabel(isPlayingNow ? "Pause" : "Spill \(episode.title)")
    }

    private var hasControls: Bool {
        menuContent != nil || !showArtwork
    }

    /// A menu button only where the row has actions of its own, plus the play
    /// button on rows with no artwork to carry it.
    ///
    /// There is deliberately no ellipsis on the browse surfaces: the long-press
    /// context menu already holds the same three items, and a second copy cost
    /// the title 48pt. Queue rows keep theirs — their actions differ, and they
    /// have no context menu, because a long press there is the reorder drag.
    ///
    /// `fixedSize` is load-bearing: the buttons set `minWidth` for the touch
    /// target and no maximum, which makes them flexible, and the row then split
    /// its spare width between them and the title instead of giving it all to
    /// the title. Pinning them to their ideal width keeps the 44pt target — and
    /// lets it grow at accessibility sizes — without competing for the text.
    @ViewBuilder
    private var controlsRow: some View {
        if hasControls {
        HStack(spacing: AppSpacing.xs) {
            if let menuContent {
                Menu {
                    menuContent()
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(Color.appMutedForeground)
                        .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Flere valg for \(episode.title)")
            }

            if !showArtwork {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if isNowPlaying {
                        playerVM.togglePlayPause()
                    } else if let onPlay {
                        onPlay()
                    } else {
                        playerVM.play(episode: episode, podcastTitle: podcastTitle, podcastImage: podcastImage)
                    }
                } label: {
                    Image(systemName: isPlayingNow ? "pause.fill" : "play.fill")
                        .font(.system(.title2))
                        .foregroundStyle(Color.appAccent)
                        .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(isPlayingNow ? "Pause" : "Spill \(episode.title)")
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        // The 44pt boxes reach into the card's own trailing padding. The glyphs
        // are centred, so they still sit well clear of the border, and the
        // title gets the width back.
        .padding(.trailing, -AppSpacing.sm)
        }
    }

    /// Date, duration and badges on one line. They used to be two stacked
    /// rows, which cost a row of height for two short strings.
    @ViewBuilder
    private func metaRow(progress p: PlaybackProgressViewModel.ProgressInfo, hasBadges: Bool) -> some View {
        if !metadataLine.isEmpty || hasBadges {
            HStack(spacing: AppSpacing.sm) {
                if isNowPlaying {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.appAccent)
                }

                if !metadataLine.isEmpty {
                    Text(metadataLine)
                        .font(.caption2Text)
                        .foregroundStyle(Color.appMutedForeground)
                        .lineLimit(1)
                }

                if p.completed {
                    Image(systemName: "checkmark")
                        .font(.system(.caption2))
                        .foregroundStyle(Color.appSuccess)
                        .accessibilityLabel("Hørt")
                } else if let fraction = p.fraction, fraction > 0.01 {
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

#Preview("Uten bilde") {
    PreviewWrapper {
        EpisodeCard(
            episode: .preview,
            podcastTitle: "Aftenpodden",
            podcastImage: "",
            showArtwork: false,
            showDescription: true
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
