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
                    Button {
                        playerVM.isExpanded = true
                    } label: {
                        HStack(spacing: AppSpacing.md) {
                            CachedAsyncImage(url: playerVM.podcastImage ?? episode.imageUrl, size: 48)

                            Text(episode.title)
                                .font(.cardTitle)
                                .foregroundStyle(Color.appForeground)
                                .lineLimit(2)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

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

                    Button {
                        playerVM.stop()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.appMutedForeground)
                    }
                    .frame(minWidth: 36, minHeight: AppSize.touchTarget)
                    .accessibilityLabel("Stopp avspilling")
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.sm)
            }
            .frame(height: AppSize.miniPlayerHeight, alignment: .top)
            .background(Color.appCard)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Spiller: \(episode.title)")
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
