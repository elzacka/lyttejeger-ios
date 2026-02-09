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
                    CachedAsyncImage(url: playerVM.podcastImage ?? episode.imageUrl, size: 48)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(episode.title)
                            .font(.cardTitle)
                            .foregroundStyle(Color.appForeground)
                            .lineLimit(1)

                        Text(playerVM.podcastTitle ?? "")
                            .font(.caption2Text)
                            .foregroundStyle(Color.appMutedForeground)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.appBorder)

                    Button {
                        playerVM.togglePlayPause()
                    } label: {
                        Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.appAccent)
                    }
                    .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                    .accessibilityLabel(playerVM.isPlaying ? "Pause" : "Spill av")

                    Button {
                        playerVM.skipForward()
                    } label: {
                        Image(systemName: "goforward.30")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.appMutedForeground)
                    }
                    .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                    .accessibilityLabel("Spol 30 sekunder frem")
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.sm)
            }
            .frame(height: AppSize.miniPlayerHeight)
            .background(Color.appCard)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.appBorder.opacity(0.4))
                    .frame(height: 1)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Spiller: \(episode.title)")
            .onTapGesture {
                playerVM.isExpanded = true
            }
            .fullScreenCover(isPresented: Binding(
                get: { playerVM.isExpanded },
                set: { playerVM.isExpanded = $0 }
            )) {
                AudioPlayerSheet()
            }
        }
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
