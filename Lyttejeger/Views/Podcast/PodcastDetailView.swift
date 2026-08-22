import SwiftUI

struct PodcastDetailView: View {
    let podcast: Podcast
    var focusEpisodeId: String? = nil

    @Environment(\.isTabActive) private var isTabActive
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
    @State private var toastTask: Task<Void, Never>?
    /// The header already shows the title, so the navigation bar only repeats
    /// it once the header has scrolled away.
    @State private var showNavTitle = false

    /// Roughly the height of the artwork row: past this the header title is
    /// behind the navigation bar.
    private static let navTitleScrollThreshold: CGFloat = 130

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

                        // Follow sits here rather than on its own line below:
                        // title and author only fill about 76 of the artwork's
                        // 120pt, and the button is the height of what was left
                        // over.
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text(pod.title)
                                .font(.sectionTitle)
                                .foregroundStyle(Color.appForeground)

                            Text(pod.author)
                                .font(.bodyText)
                                .foregroundStyle(Color.appMutedForeground)

                            subscribeButton
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Categories & explicit
                    if !pod.categories.isEmpty || pod.explicit {
                        HStack(spacing: AppSpacing.xs) {
                            if pod.explicit {
                                Text("E")
                                    .font(.badgeText)
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
                    ExpandableText(text: desc, textFont: .bodyText, textColor: .appForeground, backgroundColor: .appBackground)
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
                            .font(.system(.title2))
                            .foregroundStyle(Color.appError)

                        Text(error)
                            .font(.bodyText)
                            .foregroundStyle(Color.appError)
                            .multilineTextAlignment(.center)

                        Button {
                            self.error = nil
                            isLoading = true
                            Task { await loadEpisodes() }
                        } label: {
                            Text("Prøv igjen")
                                .font(.buttonText)
                                .foregroundStyle(Color.appAccent)
                                .padding(.horizontal, AppSpacing.lg)
                                .frame(minHeight: AppSize.touchTarget)
                                .contentShape(Rectangle())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(AppSpacing.xl)
                } else if episodes.isEmpty {
                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "waveform")
                            .font(.system(.largeTitle, weight: .light))
                            .foregroundStyle(Color.appMutedForeground)

                        Text("Ingen episoder ennå")
                            .font(.bodyText)
                            .foregroundStyle(Color.appMutedForeground)

                        Text("Denne podkasten har ikke publisert episoder vi kan vise.")
                            .font(.caption2Text)
                            .foregroundStyle(Color.appMutedForeground)
                            .multilineTextAlignment(.center)
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
                                showArtwork: false,
                                showDescription: true
                            )
                            .id(episode.id)
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                }
            }
            .padding(.bottom, AppConstants.playerBottomPadding)
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
        .animation(
            UIAccessibility.isReduceMotionEnabled ? nil : .easeInOut(duration: 0.2),
            value: isLoading
        )
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y > Self.navTitleScrollThreshold
        } action: { _, isScrolledPastHeader in
            guard showNavTitle != isScrolledPastHeader else { return }
            if UIAccessibility.isReduceMotionEnabled {
                showNavTitle = isScrolledPastHeader
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showNavTitle = isScrolledPastHeader
                }
            }
        }
        .navigationTitle(showNavTitle ? podcast.title : "")
        .navigationBarTitleDisplayMode(.inline)
        // Stays alive inside its tab's stack while another tab is on screen
        .accessibilityHidden(!isTabActive)
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
    /// (e.g. navigating from FollowingView where Subscription only stores basic fields)
    private func enrichPodcastIfNeeded() async {
        guard podcast.description.isEmpty, !podcast.isNRKFeed,
              let feedId = Int(podcast.id) else { return }
        if let response = try? await PodcastIndexAPI.shared.podcastByFeedId(feedId),
           let feed = response.feed {
            podcastInfo = PodcastTransform.transformFeed(feed)
        }
    }

    private var subscribeButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            let wasSubscribed = subscriptionVM.isSubscribed(pod.id)
            subscriptionVM.toggleSubscription(podcast: pod)
            let message = wasSubscribed ? "Fjernet fra følgelisten" : "Lagt til i følgelisten"
            if UIAccessibility.isReduceMotionEnabled {
                toastMessage = message
            } else {
                withAnimation(.easeOut(duration: 0.25)) { toastMessage = message }
            }
            UIAccessibility.post(notification: .announcement, argument: message)
            toastTask?.cancel()
            toastTask = Task {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                if UIAccessibility.isReduceMotionEnabled {
                    toastMessage = nil
                } else {
                    withAnimation { toastMessage = nil }
                }
            }
        } label: {
            Text(subscriptionVM.isSubscribed(pod.id) ? "Slutt å følge" : "Følg")
                .font(.cardTitle)
                .foregroundStyle(subscriptionVM.isSubscribed(pod.id) ? Color.appMutedForeground : .white)
                .padding(.horizontal, AppSpacing.lg)
                .frame(minHeight: AppSize.touchTarget)
                .background(subscriptionVM.isSubscribed(pod.id) ? Color.appMuted : Color.appAccent)
                .clipShape(.rect(cornerRadius: AppRadius.md))
                .contentShape(Rectangle())
        }
    }

    private func loadEpisodes() async {
        if let slug = podcast.nrkSlug {
            await loadNRKEpisodes(slug: slug)
        } else if let feedUrl = podcast.directFeedUrl {
            // Imported from OPML, unknown to Podcast Index. The feed URL is
            // all we have, so read the episodes straight from the feed.
            await loadDirectFeedEpisodes(feedUrl: feedUrl)
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
        // Catalog unavailable → no NRK match; Podcast Index episodes are used instead
        let matches = (try? await NRKPodcastService.shared.searchCatalog(query: podcast.title)) ?? []
        return matches.first { $0.title.lowercased() == podcast.title.lowercased() }?.nrkSlug
    }

    private func loadPodcastIndexEpisodes() async {
        guard let feedId = Int(podcast.id) else {
            error = "Ugyldig podkast-ID"
            isLoading = false
            return
        }

        defer { isLoading = false }

        do {
            let response = try await PodcastIndexAPI.shared.episodesByFeedId(feedId, max: 100)
            episodes = PodcastTransform.transformEpisodes(response.items ?? [])
        } catch is URLError {
            self.error = "Ingen nettverkstilkobling.\nSjekk tilkoblingen og prøv igjen."
        } catch {
            self.error = "Kunne ikke laste episoder.\nPrøv igjen senere."
        }
    }

    private func loadDirectFeedEpisodes(feedUrl: String) async {
        defer { isLoading = false }

        do {
            let result = try await RSSFeedService.shared.fetchEpisodes(
                feedUrl: feedUrl,
                podcastId: podcast.id
            )
            episodes = result.episodes

            // The subscription only carries what the OPML file said, so fill
            // in artwork and description from the feed itself
            if !result.podcastImageUrl.isEmpty {
                nrkImageUrl = result.podcastImageUrl
            }
            if !result.podcastDescription.isEmpty {
                nrkDescription = result.podcastDescription
            }
        } catch is URLError {
            self.error = "Ingen nettverkstilkobling.\nSjekk tilkoblingen og prøv igjen."
        } catch {
            self.error = "Kunne ikke laste episoder fra feeden.\nPrøv igjen senere."
        }
    }

    private func loadNRKEpisodes(slug: String) async {
        defer { isLoading = false }

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
        } catch is URLError {
            self.error = "Ingen nettverkstilkobling.\nSjekk tilkoblingen og prøv igjen."
        } catch {
            self.error = "Kunne ikke laste NRK-episoder.\nPrøv igjen senere."
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
