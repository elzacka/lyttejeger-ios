import SwiftUI

struct AudioPlayerSheet: View {
    @Environment(AudioPlayerViewModel.self) private var playerVM
    @Environment(\.dismiss) private var dismiss
    @State private var showChapters = false
    @State private var showTranscript = false

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.xl) {
                Spacer()

                // Artwork
                if let imageUrl = playerVM.podcastImage ?? playerVM.currentEpisode?.imageUrl {
                    CachedAsyncImage(url: imageUrl, size: AppSize.artworkLarge)
                        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                }

                // Title & podcast
                VStack(spacing: AppSpacing.xs) {
                    Text(playerVM.currentEpisode?.title ?? "")
                        .font(.sectionTitle)
                        .foregroundStyle(Color.appForeground)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Text(playerVM.podcastTitle ?? "")
                        .font(.bodyText)
                        .foregroundStyle(Color.appMutedForeground)
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
            .background(Color.appBackground)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.appMutedForeground)
                    }
                    .accessibilityLabel("Lukk spiller")
                }
            }
            .sheet(isPresented: $showChapters) {
                ChapterPanel()
            }
            .sheet(isPresented: $showTranscript) {
                TranscriptPanel()
            }
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
