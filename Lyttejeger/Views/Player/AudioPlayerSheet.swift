import SwiftUI

struct AudioPlayerSheet: View {
    @Environment(AudioPlayerViewModel.self) private var playerVM
    @State private var showChapters = false
    @State private var showTranscript = false

    private func navigateToPodcast() {
        guard let episode = playerVM.currentEpisode else { return }
        playerVM.pendingPodcastRoute = PodcastRoute(
            podcast: .minimal(
                id: episode.podcastId,
                title: playerVM.podcastTitle ?? "",
                imageUrl: playerVM.podcastImage ?? episode.imageUrl ?? ""
            ),
            focusEpisodeId: episode.id
        )
        playerVM.isExpanded = false
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: AppSpacing.xl) {
                Spacer()

                // Artwork (tap to view podcast)
                if let imageUrl = playerVM.podcastImage ?? playerVM.currentEpisode?.imageUrl {
                    Button {
                        navigateToPodcast()
                    } label: {
                        CachedAsyncImage(url: imageUrl, size: AppSize.artworkLarge)
                            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Vis podcast")
                }

                // Title & podcast
                VStack(spacing: AppSpacing.xs) {
                    Text(playerVM.currentEpisode?.title ?? "")
                        .font(.sectionTitle)
                        .foregroundStyle(Color.appForeground)
                        .lineLimit(3)
                        .multilineTextAlignment(.center)

                    Button {
                        navigateToPodcast()
                    } label: {
                        Text(playerVM.podcastTitle ?? "")
                            .font(.bodyText)
                            .foregroundStyle(Color.appMutedForeground)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppSpacing.lg)

                // Player controls
                PlayerControls()

                // Feature buttons
                HStack(spacing: AppSpacing.xl) {
                    if !playerVM.chapters.isEmpty {
                        Button {
                            showChapters = true
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "list.number")
                                    .font(.system(size: 20))
                                Text("Kapitler")
                                    .font(.caption2Text)
                            }
                            .foregroundStyle(Color.appAccent)
                        }
                        .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                    }

                    if playerVM.transcript != nil {
                        Button {
                            showTranscript = true
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "text.quote")
                                    .font(.system(size: 20))
                                Text("Transkripsjon")
                                    .font(.caption2Text)
                            }
                            .foregroundStyle(Color.appAccent)
                        }
                        .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                    }
                }

                Spacer()

                // Brand watermark
                HStack(spacing: AppSpacing.xs) {
                    Image("LaunchLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .opacity(0.3)
                    Text("Lyttejeger")
                        .font(.caption2Text)
                        .foregroundStyle(Color.appBorder)
                }
                .padding(.bottom, AppSpacing.sm)
            }
            .padding(AppSpacing.lg)

            // Top bar buttons (no toolbar to avoid iOS 26 circular backgrounds)
            HStack {
                Button {
                    playerVM.isExpanded = false
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.appMutedForeground)
                }
                .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                .accessibilityLabel("Lukk spiller")

                Spacer()

                if let episode = playerVM.currentEpisode,
                   let url = URL(string: episode.audioUrl) {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.appMutedForeground)
                    }
                    .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                    .accessibilityLabel("Del episode")
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
        }
        .background(Color.appBackground)
        .sheet(isPresented: $showChapters) {
            ChapterPanel()
        }
        .sheet(isPresented: $showTranscript) {
            TranscriptPanel()
        }
    }
}

#if DEBUG
#Preview("Full spiller") {
    PreviewWrapper(player: .playing) {
        AudioPlayerSheet()
    }
}
#endif
