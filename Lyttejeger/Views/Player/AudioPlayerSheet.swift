import SwiftUI

struct AudioPlayerSheet: View {
    @Environment(AudioPlayerViewModel.self) private var playerVM
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showChapters = false
    @State private var showTranscript = false
    @State private var isDownloading = false
    @State private var downloadError: String?
    @State private var showDownloadError = false

    /// Drives both the feature row itself and the height budgeted for it, so
    /// the artwork can never be sized for a row that is not there.
    private var showsFeatureRow: Bool {
        !playerVM.chapters.isEmpty || playerVM.transcript != nil
            || playerVM.chaptersFailed || playerVM.transcriptFailed
    }

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
            // Only accessibility sizes need to scroll. A scroll view at normal
            // sizes competes with the progress slider's drag and swallows its
            // end-of-drag callback, which leaves the position display frozen
            // while audio keeps playing.
            GeometryReader { geo in
                if dynamicTypeSize.isAccessibilitySize {
                    ScrollView {
                        content(artworkSide: AppSize.artworkMedium)
                            .frame(minHeight: geo.size.height)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                } else {
                    content(artworkSide: Self.artworkSide(in: geo.size, hasFeatureRow: showsFeatureRow))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            topBar
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
        .alert("Nedlasting feilet", isPresented: $showDownloadError) {
            Button("OK") { }
        } message: {
            Text(downloadError ?? "")
        }
    }

    /// Vertical space the artwork has to leave for everything else in the
    /// stack. Budgeted against a two-line title with one extra line of slack,
    /// because reserving for the three-line worst case on every screen costs
    /// the artwork ~80pt it almost always has room for.
    ///
    /// Note the size this is subtracted from is the safe-area height, not the
    /// screen height — about 781pt on an iPhone 17 Pro rather than 874.
    static func reservedContentHeight(hasFeatureRow: Bool) -> CGFloat {
        // Component heights are measured from the rendered screen at the
        // default text size, not derived from font metrics — guessing them
        // high is what left the artwork smaller than the space allowed.
        let topClearance = AppSize.touchTarget
        let titleAndPodcast: CGFloat = 105
        let transport: CGFloat = 105
        let watermark = 14 + AppSpacing.sm
        let featureRow = hasFeatureRow ? 38 + AppSpacing.lg : 0
        let stackSpacing = AppSpacing.lg * 5
        let stackPadding = AppSpacing.lg * 2
        // Room for a third title line before anything has to truncate. Larger
        // Dynamic Type sizes eat into this; past it the artwork gives way
        // first, since it is the only element sized from what is left over.
        let slack: CGFloat = 60
        return topClearance + titleAndPodcast + transport + watermark
            + featureRow + stackSpacing + stackPadding + slack
    }

    /// The artwork was a hard 280pt on every device. On a 440pt-wide Pro Max
    /// that wasted ~130pt of width and pushed all the surplus height into dead
    /// air above the image. Sizing it from the space actually available turns
    /// that air into artwork, and still shrinks on small screens or when
    /// Dynamic Type grows the text around it.
    static func artworkSide(in size: CGSize, hasFeatureRow: Bool) -> CGFloat {
        let widthCeiling = size.width - AppSpacing.lg * 2
        let heightCeiling = size.height - reservedContentHeight(hasFeatureRow: hasFeatureRow)
        return max(AppSize.artworkMedium, min(widthCeiling, heightCeiling))
    }

    private func content(artworkSide: CGFloat) -> some View {
        VStack(spacing: AppSpacing.lg) {
                // Clears the overlaid top bar. Capped as well as floored: as an
                // open-ended Spacer it soaked up most of the leftover height on
                // tall screens, which is what put ~270pt of nothing above the
                // artwork on a Pro Max.
                Spacer()
                    .frame(
                        minHeight: AppSize.touchTarget,
                        maxHeight: AppSize.touchTarget + AppSpacing.xxl
                    )

                // Artwork (tap to view podcast)
                if let imageUrl = playerVM.podcastImage ?? playerVM.currentEpisode?.imageUrl {
                    Button {
                        navigateToPodcast()
                    } label: {
                        CachedAsyncImage(url: imageUrl, size: artworkSide)
                            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                    }
                    .buttonStyle(CardButtonStyle())
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
                            .foregroundStyle(Color.appAccent)
                            .multilineTextAlignment(.center)
                            .frame(minHeight: AppSize.touchTarget)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Vis podkasten \(playerVM.podcastTitle ?? "")")
                }
                .padding(.horizontal, AppSpacing.lg)

                if playerVM.hasError {
                    VStack(spacing: AppSpacing.sm) {
                        Text("Kunne ikke spille av episoden.")
                            .font(.smallText)
                            .foregroundStyle(Color.appError)
                        Button {
                            // Read everything before play(): it starts with
                            // stop(), which clears the current episode.
                            if let episode = playerVM.currentEpisode {
                                let title = playerVM.podcastTitle
                                let image = playerVM.podcastImage
                                playerVM.play(episode: episode, podcastTitle: title, podcastImage: image)
                            }
                        } label: {
                            Text("Prøv igjen")
                                .font(.buttonText)
                                .foregroundStyle(Color.appAccent)
                                .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Prøv å spille av episoden på nytt")
                    }
                }

                // Player controls
                PlayerControls()

                // Feature buttons
                if showsFeatureRow {
                    HStack(spacing: AppSpacing.xl) {
                        if !playerVM.chapters.isEmpty || playerVM.chaptersFailed {
                            Button {
                                showChapters = true
                            } label: {
                                VStack(spacing: AppSpacing.xs) {
                                    Image(systemName: playerVM.chaptersFailed
                                        ? "exclamationmark.triangle" : "list.number")
                                        .font(.system(.title3))
                                    Text("Kapitler")
                                        .font(.caption2Text)
                                }
                                .foregroundStyle(playerVM.chaptersFailed ? Color.appError : Color.appAccent)
                                .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                                .contentShape(Rectangle())
                            }
                            .accessibilityLabel("Vis kapitler")
                        }

                        if playerVM.transcript != nil || playerVM.transcriptFailed {
                            Button {
                                showTranscript = true
                            } label: {
                                VStack(spacing: AppSpacing.xs) {
                                    Image(systemName: playerVM.transcriptFailed
                                        ? "exclamationmark.triangle" : "text.quote")
                                        .font(.system(.title3))
                                    Text("Transkripsjon")
                                        .font(.caption2Text)
                                }
                                .foregroundStyle(playerVM.transcriptFailed ? Color.appError : Color.appAccent)
                                .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                                .contentShape(Rectangle())
                            }
                            .accessibilityLabel("Vis transkripsjon")
                        }
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
                        .foregroundStyle(Color.appMutedForeground.opacity(0.8))
                }
                .padding(.bottom, AppSpacing.sm)
        }
        .padding(AppSpacing.lg)
    }

    /// Top bar buttons (no toolbar to avoid iOS 26 circular backgrounds).
    ///
    /// `fullScreenCover` has no interactive dismissal, so the header doubles as
    /// the pull-down target people expect from a now-playing screen. The gesture
    /// lives here rather than on the content, where it would fight the scroll
    /// view and the progress slider.
    private var topBar: some View {
            HStack {
                Button {
                    playerVM.isExpanded = false
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(Color.appMutedForeground)
                        .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Lukk spiller")

                Spacer()

                if playerVM.currentEpisode != nil {
                    Button {
                        Task { await downloadAndShare() }
                    } label: {
                        Group {
                            if isDownloading {
                                ProgressView()
                                    .tint(Color.appMutedForeground)
                            } else {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(.callout, weight: .medium))
                                    .foregroundStyle(Color.appMutedForeground)
                            }
                        }
                        .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                        .contentShape(Rectangle())
                    }
                    .disabled(isDownloading)
                    .accessibilityLabel("Eksporter lydfil")
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .background(Color.appBackground)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        if value.translation.height > 80, abs(value.translation.width) < 80 {
                            playerVM.isExpanded = false
                        }
                    }
            )
    }

    private func downloadAndShare() async {
        // https only — ATS blocks plain-http URLSession transfers anyway
        // (NSAllowsArbitraryLoadsForMedia covers only AV playback)
        guard let episode = playerVM.currentEpisode,
              let url = URL(string: episode.audioUrl),
              url.scheme == "https" else { return }

        isDownloading = true
        defer { isDownloading = false }

        do {
            let (tempURL, _) = try await URLSession.shared.download(from: url)
            let invalidChars = CharacterSet(charactersIn: "/:\\?%*|\"<>")
            var safeName = String(
                episode.title
                    .components(separatedBy: invalidChars)
                    .joined(separator: "-")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .prefix(200)
            )
            // No leading dots — avoids hidden files and "." path components
            safeName = safeName.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            if safeName.isEmpty { safeName = "episode" }
            let ext = url.pathExtension.isEmpty ? "mp3" : url.pathExtension
            let destURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(safeName)
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
            showDownloadError = true
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
