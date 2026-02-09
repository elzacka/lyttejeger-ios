import SwiftUI

struct PodcastDetailView: View {
    let podcast: Podcast

    @Environment(SubscriptionViewModel.self) private var subscriptionVM
    @Environment(AudioPlayerViewModel.self) private var playerVM
    @Environment(QueueViewModel.self) private var queueVM
    @State private var episodes: [Episode] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var isDescriptionExpanded = false
    @State private var nrkImageUrl: String?
    @State private var nrkDescription: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Header
                HStack(alignment: .top, spacing: AppSpacing.lg) {
                    CachedAsyncImage(url: nrkImageUrl ?? podcast.imageUrl, size: AppSize.artworkMedium)

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text(podcast.title)
                            .font(.sectionTitle)
                            .foregroundStyle(Color.appForeground)

                        Text(podcast.author)
                            .font(.bodyText)
                            .foregroundStyle(Color.appMutedForeground)

                        HStack(spacing: AppSpacing.xs) {
                            ForEach(podcast.categories.prefix(3), id: \.self) { category in
                                Text(translateCategory(category))
                                    .font(.caption2Text)
                                    .foregroundStyle(Color.appAccent)
                                    .padding(.horizontal, AppSpacing.sm)
                                    .padding(.vertical, 2)
                                    .background(Color.appAccent.opacity(0.1))
                                    .clipShape(.rect(cornerRadius: AppRadius.sm))
                            }
                        }

                        // Subscribe button
                        Button {
                            UINotificationFeedbackGenerator().notificationOccurred(
                                subscriptionVM.isSubscribed(podcast.id) ? .warning : .success
                            )
                            subscriptionVM.toggleSubscription(podcast: podcast)
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
                    }
                }
                .padding(.horizontal, AppSpacing.lg)

                // Description
                if let desc = nrkDescription ?? (podcast.description.isEmpty ? nil : podcast.description) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(desc)
                            .font(.bodyText)
                            .foregroundStyle(Color.appForeground)
                            .lineLimit(isDescriptionExpanded ? nil : 4)

                        Text(isDescriptionExpanded ? "Vis mindre" : "Vis mer")
                            .font(.caption2Text)
                            .foregroundStyle(Color.appAccent)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if UIAccessibility.isReduceMotionEnabled {
                            isDescriptionExpanded.toggle()
                        } else {
                            withAnimation(.easeOut(duration: 0.2)) {
                                isDescriptionExpanded.toggle()
                            }
                        }
                    }
                    .accessibilityHint(isDescriptionExpanded ? "Trykk for å skjule beskrivelse" : "Trykk for å vise hele beskrivelsen")
                    .padding(.horizontal, AppSpacing.lg)
                }

                Divider().background(Color.appBorder)

                // Episodes
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Laster episoder...")
                            .font(.bodyText)
                        Spacer()
                    }
                    .padding(.top, AppSpacing.xl)
                } else if let error {
                    VStack(spacing: AppSpacing.sm) {
                        Text(error)
                            .font(.bodyText)
                            .foregroundStyle(Color.appError)
                        Button("Prøv igjen") {
                            self.error = nil
                            isLoading = true
                            Task { await loadEpisodes() }
                        }
                        .font(.buttonText)
                        .foregroundStyle(Color.appAccent)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                } else {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(episodes) { episode in
                            EpisodeRow(
                                episode: episode,
                                podcastTitle: podcast.title,
                                podcastImage: nrkImageUrl ?? podcast.imageUrl
                            )
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                }
            }
            .padding(.bottom, 100)
        }
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                episodes = Episode.previewList
                isLoading = false
                return
            }
            #endif
            await loadEpisodes()
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
        } catch {
            self.error = "Kunne ikke laste episoder"
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
        } catch {
            self.error = "Kunne ikke laste NRK-episoder"
            isLoading = false
        }
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
