import SwiftUI

struct AudioPlayerSheet: View {
    @Environment(AudioPlayerViewModel.self) private var playerVM
    @State private var showChapters = false
    @State private var showTranscript = false
    @State private var isDownloading = false
    @State private var downloadError: String?

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
                            VStack(spacing: AppSpacing.xs) {
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
                            VStack(spacing: AppSpacing.xs) {
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

                if playerVM.currentEpisode != nil {
                    Button {
                        Task { await downloadAndShare() }
                    } label: {
                        if isDownloading {
                            ProgressView()
                                .tint(Color.appMutedForeground)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.appMutedForeground)
                        }
                    }
                    .disabled(isDownloading)
                    .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                    .accessibilityLabel("Eksporter lydfil")
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
        }
        .background(Color.appBackground)
        .sheet(isPresented: $showChapters) {
            ChapterPanel()
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.appBackground)
        }
        .sheet(isPresented: $showTranscript) {
            TranscriptPanel()
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.appBackground)
        }
        .alert("Nedlasting feilet", isPresented: Binding(
            get: { downloadError != nil },
            set: { if !$0 { downloadError = nil } }
        )) {
            Button("OK") { downloadError = nil }
        } message: {
            Text(downloadError ?? "")
        }
    }

    private func downloadAndShare() async {
        guard let episode = playerVM.currentEpisode,
              let url = URL(string: episode.audioUrl) else { return }

        isDownloading = true
        defer { isDownloading = false }

        do {
            let (tempURL, _) = try await URLSession.shared.download(from: url)
            let invalidChars = CharacterSet(charactersIn: "/:\\?%*|\"<>")
            let safeName = episode.title
                .components(separatedBy: invalidChars)
                .joined(separator: "-")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(200)
            let ext = url.pathExtension.isEmpty ? "mp3" : url.pathExtension
            let destURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(String(safeName))
                .appendingPathExtension(ext)
            try? FileManager.default.removeItem(at: destURL)
            try FileManager.default.moveItem(at: tempURL, to: destURL)

            await MainActor.run {
                let activityVC = UIActivityViewController(activityItems: [destURL], applicationActivities: nil)
                activityVC.completionWithItemsHandler = { _, _, _, _ in
                    try? FileManager.default.removeItem(at: destURL)
                }
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.keyWindow?.rootViewController {
                    var topVC = rootVC
                    while let presented = topVC.presentedViewController {
                        topVC = presented
                    }
                    topVC.present(activityVC, animated: true)
                }
            }
        } catch {
            downloadError = "Kunne ikke laste ned lydfilen. Sjekk nettverkstilkoblingen og prøv igjen."
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
