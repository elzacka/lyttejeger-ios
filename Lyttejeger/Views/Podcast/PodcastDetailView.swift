import SwiftUI

struct PodcastDetailView: View {
    let podcast: Podcast
    var focusEpisodeId: String? = nil

    @Environment(SubscriptionViewModel.self) private var subscriptionVM
    @Environment(AudioPlayerViewModel.self) private var playerVM
    @Environment(QueueViewModel.self) private var queueVM
    @State private var podcastInfo: Podcast?
    @State private var episodes: [Episode] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var nrkImageUrl: String?
    @State private var nrkDescription: String?
    @State private var toastMessage: String?

    /// Enriched podcast data (fetched from API when initial data is incomplete)
    private var pod: Podcast { podcastInfo ?? podcast }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    HStack(alignment: .top, spacing: AppSpacing.lg) {
                        CachedAsyncImage(url: nrkImageUrl ?? pod.imageUrl, size: AppSize.artworkMedium)

                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text(pod.title)
                                .font(.sectionTitle)
                                .foregroundStyle(Color.appForeground)

                            Text(pod.author)
                                .font(.bodyText)
                                .foregroundStyle(Color.appMutedForeground)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Subscribe button
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        let wasSubscribed = subscriptionVM.isSubscribed(podcast.id)
                        subscriptionVM.toggleSubscription(podcast: podcast)
                        toastMessage = wasSubscribed ? "Fjernet fra Mine podder" : "Lagt til Mine podder"
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation { toastMessage = nil }
                        }
                    } label: {
                        Text(subscriptionVM.isSubscribed(podcast.id) ? "Slutt å følge" : "Følg")
                            .font(.buttonText)
                            .foregroundStyle(subscriptionVM.isSubscribed(podcast.id) ? Color.appMutedForeground : .white)
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, AppSpacing.sm)
                            .background(subscriptionVM.isSubscribed(podcast.id) ? Color.appMuted : Color.appAccent)
                            .clipShape(.rect(cornerRadius: AppRadius.md))
                    }
                    .frame(minHeight: AppSize.touchTarget)

                    // Categories & explicit
                    if !pod.categories.isEmpty || pod.explicit {
                        HStack(spacing: AppSpacing.xs) {
                            if pod.explicit {
                                Text("E")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color.appMutedForeground)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.appBorder.opacity(0.4))
                                    .clipShape(.rect(cornerRadius: 3))
                                    .accessibilityLabel("Eksplisitt innhold")
                            }

                            ForEach(pod.categories.prefix(3), id: \.self) { category in
                                Text(translateCategory(category))
                                    .font(.caption2Text)
                                    .foregroundStyle(Color.appAccent)
                                    .padding(.horizontal, AppSpacing.sm)
                                    .padding(.vertical, 2)
                                    .background(Color.appAccent.opacity(0.1))
                                    .clipShape(.rect(cornerRadius: AppRadius.sm))
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)

                // Description
                if let desc = nrkDescription ?? (pod.description.isEmpty ? nil : pod.description) {
                    ExpandableText(text: desc, textFont: .bodyText, textColor: .appForeground)
                        .padding(.horizontal, AppSpacing.lg)
                }

                Divider().background(Color.appBorder)

                // Episodes
                if isLoading {
                    // Skeleton placeholders
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(0..<4, id: \.self) { _ in
                            SkeletonEpisodeRow()
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                } else if let error {
                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.appBorder)

                        Text(error)
                            .font(.bodyText)
                            .foregroundStyle(Color.appError)
                            .multilineTextAlignment(.center)

                        Button("Prøv igjen") {
                            self.error = nil
                            isLoading = true
                            Task { await loadEpisodes() }
                        }
                        .font(.buttonText)
                        .foregroundStyle(Color.appAccent)
                        .frame(minHeight: AppSize.touchTarget)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(AppSpacing.xl)
                } else {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(episodes) { episode in
                            EpisodeCard(
                                episode: episode,
                                podcastTitle: pod.title,
                                podcastImage: nrkImageUrl ?? pod.imageUrl,
                                showArtwork: false
                            )
                            .id(episode.id)
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                }
            }
            .padding(.bottom, 100)
        }
        .background(Color.appBackground)
        .overlay(alignment: .bottom) {
            if let message = toastMessage {
                Text(message)
                    .font(.smallText)
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.sm)
                    .background(Color.appAccent)
                    .clipShape(.rect(cornerRadius: AppRadius.md))
                    .padding(.bottom, AppSpacing.xxxl)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                episodes = Episode.previewList
                isLoading = false
                return
            }
            #endif
            async let episodesTask: () = loadEpisodes()
            async let enrichTask: () = enrichPodcastIfNeeded()
            _ = await (episodesTask, enrichTask)
        }
        .onChange(of: isLoading) { old, new in
            if old && !new, let focusId = focusEpisodeId {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(300))
                    if UIAccessibility.isReduceMotionEnabled {
                        proxy.scrollTo(focusId, anchor: .center)
                    } else {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(focusId, anchor: .center)
                        }
                    }
                }
            }
        }
        } // ScrollViewReader
    }

    /// Fetches full podcast data from API when initial data is incomplete
    /// (e.g. navigating from MyPodsView where Subscription only stores basic fields)
    private func enrichPodcastIfNeeded() async {
        guard podcast.description.isEmpty, !podcast.isNRKFeed,
              let feedId = Int(podcast.id) else { return }
        if let response = try? await PodcastIndexAPI.shared.podcastByFeedId(feedId),
           let feed = response.feed {
            podcastInfo = PodcastTransform.transformFeed(feed)
        }
    }

    private func loadEpisodes() async {
        if let slug = podcast.nrkSlug {
            await loadNRKEpisodes(slug: slug)
        } else if let slug = await findNRKSlug() {
            // PI podcast that also exists in NRK catalog — prefer RSS (better durations)
            await loadNRKEpisodes(slug: slug)
        } else {
            await loadPodcastIndexEpisodes()
        }
    }

    /// Checks if this podcast has an NRK equivalent by title match.
    /// The NRK catalog is cached, so this is essentially free after first search.
    private func findNRKSlug() async -> String? {
        let matches = await NRKPodcastService.shared.searchCatalog(query: podcast.title)
        return matches.first { $0.title.lowercased() == podcast.title.lowercased() }?.nrkSlug
    }

    private func loadPodcastIndexEpisodes() async {
        guard let feedId = Int(podcast.id) else {
            error = "Ugyldig podcast-ID"
            isLoading = false
            return
        }

        do {
            let response = try await PodcastIndexAPI.shared.episodesByFeedId(feedId, max: 100)
            episodes = PodcastTransform.transformEpisodes(response.items ?? [])
            isLoading = false
        } catch is URLError {
            self.error = "Ingen nettverkstilkobling.\nSjekk tilkoblingen og prøv igjen."
            isLoading = false
        } catch {
            self.error = "Kunne ikke laste episoder.\nPrøv igjen senere."
            isLoading = false
        }
    }

    private func loadNRKEpisodes(slug: String) async {
        do {
            let result = try await NRKPodcastService.shared.fetchEpisodes(nrkSlug: slug)
            episodes = result.episodes

            // Update metadata from RSS (catalog only has title)
            if !result.podcastImageUrl.isEmpty {
                nrkImageUrl = result.podcastImageUrl
            }
            if !result.podcastDescription.isEmpty {
                nrkDescription = result.podcastDescription
            }

            isLoading = false
        } catch is URLError {
            self.error = "Ingen nettverkstilkobling.\nSjekk tilkoblingen og prøv igjen."
            isLoading = false
        } catch {
            self.error = "Kunne ikke laste NRK-episoder.\nPrøv igjen senere."
            isLoading = false
        }
    }
}

// MARK: - Skeleton Loading

private struct SkeletonEpisodeRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.appBorder.opacity(0.4))
                        .frame(height: 14)
                        .frame(maxWidth: 200)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.appBorder.opacity(0.3))
                        .frame(height: 11)
                        .frame(maxWidth: 120)
                }
                Spacer()
            }
        }
        .padding(AppSpacing.md)
        .background(Color.appCard)
        .clipShape(.rect(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(Color.appBorder, lineWidth: 1)
        )
    }
}

#if DEBUG
#Preview("Med episoder") {
    PreviewWrapper {
        NavigationStack {
            PodcastDetailView(podcast: .preview)
        }
    }
}
#endif
