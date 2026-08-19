import SwiftUI

/// Isolated sub-view that reads currentTime/duration so only it re-renders every 0.5s
private struct MiniProgressBar: View {
    @Environment(AudioPlayerViewModel.self) private var playerVM

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(Color.appAccent)
                .frame(width: playerVM.duration > 0
                    ? geo.size.width * (playerVM.currentTime / playerVM.duration)
                    : 0
                )
        }
        .frame(height: 2)
        .background(Color.appBorder)
        .accessibilityElement()
        .accessibilityLabel("Fremdrift")
        .accessibilityValue("\(Int(playerVM.duration > 0 ? playerVM.currentTime / playerVM.duration * 100 : 0)) prosent")
    }
}

struct AudioPlayerBar: View {
    @Environment(AudioPlayerViewModel.self) private var playerVM

    var body: some View {
        if let episode = playerVM.currentEpisode {
            VStack(spacing: 0) {
                MiniProgressBar()

                HStack(spacing: AppSpacing.md) {
                    artworkPlayButton(for: episode)

                    // Title — expands player
                    Button {
                        playerVM.isExpanded = true
                    } label: {
                        Text(episode.title)
                            .font(.cardTitle)
                            .foregroundStyle(Color.appForeground)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(CardButtonStyle())
                    .accessibilityLabel("Åpne spiller")
                    .accessibilityHint(episode.title)

                    Button {
                        playerVM.skipForward()
                    } label: {
                        Image(systemName: "goforward.30")
                            .font(.system(.body))
                            .foregroundStyle(Color.appMutedForeground)
                            .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Spol 30 sekunder frem")

                    Button {
                        playerVM.stop()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(Color.appMutedForeground)
                            .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Stopp avspilling")
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.sm)
            }
            .frame(minHeight: AppSize.miniPlayerHeight, alignment: .top)
            .background(Color.appCard)
            .accessibilityElement(children: .contain)
            .fullScreenCover(isPresented: Bindable(playerVM).isExpanded) {
                AudioPlayerSheet()
            }
        }
    }

    /// The artwork is the transport, as in `EpisodeCard`. It replaces a
    /// separate play button that took ~52pt from a title already clipped at two
    /// lines, and the podcast stays reachable through the full player, where
    /// the podcast name is its own link. The overlay circle is opaque so
    /// contrast does not depend on the artwork behind it.
    private func artworkPlayButton(for episode: Episode) -> some View {
        Button {
            // On error the transport is inert (AudioService guards
            // togglePlayPause on hasError), so the same control retries the
            // episode instead of doing nothing.
            if playerVM.hasError {
                let title = playerVM.podcastTitle
                let image = playerVM.podcastImage
                playerVM.play(episode: episode, podcastTitle: title, podcastImage: image)
            } else {
                playerVM.togglePlayPause()
            }
        } label: {
            CachedAsyncImage(url: playerVM.podcastImage ?? episode.imageUrl, size: 48)
                .overlay {
                    ZStack {
                        Circle()
                            .fill(playerVM.hasError ? Color.appError : Color.appAccent)
                            .frame(width: 26, height: 26)

                        if playerVM.isLoading {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(.white)
                        } else {
                            Image(
                                systemName: playerVM.hasError
                                    ? "exclamationmark"
                                    : playerVM.isPlaying ? "pause.fill" : "play.fill"
                            )
                            .font(.system(.caption, weight: .bold))
                            .foregroundStyle(.white)
                        }
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(CardButtonStyle())
        .accessibilityLabel(
            playerVM.isLoading ? "Laster episoden"
                : playerVM.hasError ? "Kunne ikke spille av episoden. Prøv igjen"
                : playerVM.isPlaying ? "Pause" : "Spill av"
        )
    }
}

#if DEBUG
#Preview("Spiller") {
    PreviewWrapper(player: .playing) {
        AudioPlayerBar()
    }
}

#Preview("Pause") {
    PreviewWrapper(player: .paused) {
        AudioPlayerBar()
    }
}
#endif
