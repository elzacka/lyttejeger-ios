import SwiftUI

struct HomeView: View {
    @Environment(SearchViewModel.self) private var searchVM
    @Environment(SubscriptionViewModel.self) private var subscriptionVM
    @Environment(AudioPlayerViewModel.self) private var playerVM
    @Environment(PlaybackProgressViewModel.self) private var progressVM
    @State private var showFilters = false
    @FocusState private var isSearchFocused: Bool

    // Home sections
    @AppStorage("showLastPlayed") private var showLastPlayed = true
    @AppStorage("showNewFromSubscriptions") private var showNewFromSubscriptions = true
    @State private var lastPlayedInfo: LastPlayedInfo?
    @State private var recentEpisodes: [RecentEpisodeData] = []
    @State private var isLoadingRecent = false

    private var isHomeState: Bool {
        !searchVM.isLoading && searchVM.error == nil && searchVM.filters.query.isEmpty && searchVM.podcasts.isEmpty && !searchVM.hasActiveFilters
    }

    private var lastPlayedEpisode: (episode: Episode, podcastTitle: String, podcastImage: String)? {
        if let ep = playerVM.currentEpisode, !progressVM.isCompleted(ep.id) {
            return (ep, playerVM.podcastTitle ?? "", playerVM.podcastImage ?? "")
        }
        if let info = lastPlayedInfo, !progressVM.isCompleted(info.episodeId) {
            return (info.toEpisode(), info.podcastTitle, info.podcastImage)
        }
        return nil
    }

    private var hasHomeContent: Bool {
        (showLastPlayed && lastPlayedEpisode != nil) || (showNewFromSubscriptions && !recentEpisodes.isEmpty)
    }

    var body: some View {
        @Bindable var vm = searchVM

        VStack(spacing: 0) {
            // Search + tabs toolbar
            VStack(spacing: AppSpacing.md) {
                // Brand wordmark
                HStack(spacing: AppSpacing.sm) {
                    Image("LaunchLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)

                    Text("Lyttejeger")
                        .font(.sectionTitle)
                        .foregroundStyle(Color.appForeground)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.md)

                // Search field — warm, understated, belongs to the beige world
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.appAccent.opacity(0.6))
                        .font(.system(size: 16))

                    TextField(vm.activeTab == .podcasts ? "Søk etter podkaster..." : "Søk etter episoder...", text: Binding(
                        get: { searchVM.filters.query },
                        set: { searchVM.setQuery($0) }
                    ))
                    .font(.bodyText)
                    .foregroundStyle(Color.appForeground)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($isSearchFocused)
                    .submitLabel(.search)

                    if !searchVM.filters.query.isEmpty {
                        Button {
                            searchVM.setQuery("")
                            isSearchFocused = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.appBorder)
                        }
                        .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                    }

                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: searchVM.activeFilterCount > 0
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(searchVM.activeFilterCount > 0 ? Color.appAccent : Color.appAccent.opacity(0.6))
                    }
                    .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                    .accessibilityLabel(searchVM.activeFilterCount > 0 ? "Filter, \(searchVM.activeFilterCount) aktive" : "Filter")
                }
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 44)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.appBorder.opacity(0.4))
                        .frame(height: 1)
                }

                // Tab switcher
                HStack(spacing: 0) {
                    ForEach(SearchViewModel.SearchTab.allCases, id: \.self) { tab in
                        Button {
                            if UIAccessibility.isReduceMotionEnabled {
                                vm.activeTab = tab
                            } else {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    vm.activeTab = tab
                                }
                            }
                        } label: {
                            Text(tab == .podcasts ? "Podkaster" : "Episoder")
                                .font(.buttonText)
                                .foregroundStyle(vm.activeTab == tab ? Color.appAccent : Color.appMutedForeground)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.xs)
                        }
                        .accessibilityAddTraits(vm.activeTab == tab ? .isSelected : [])
                    }
                }
                .overlay(alignment: .bottom) {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.appAccent)
                            .frame(width: geo.size.width / 2, height: 2)
                            .offset(x: vm.activeTab == .podcasts ? 0 : geo.size.width / 2)
                            .animation(UIAccessibility.isReduceMotionEnabled ? nil : .easeOut(duration: 0.2), value: vm.activeTab)
                    }
                    .frame(height: 2)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.sm)

            // Results / Home
            if isHomeState {
                if hasHomeContent {
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppSpacing.xl) {
                            // Continue listening section
                            if showLastPlayed, let last = lastPlayedEpisode {
                                homeSection("Fortsett å lytte", icon: "play.circle") {
                                    EpisodeCard(
                                        episode: last.episode,
                                        podcastTitle: last.podcastTitle,
                                        podcastImage: last.podcastImage
                                    )
                                }
                            }

                            // New from subscriptions
                            if showNewFromSubscriptions && !recentEpisodes.isEmpty {
                                homeSection("Nytt fra Mine podder", icon: "heart.fill") {
                                    ForEach(recentEpisodes) { item in
                                        EpisodeCard(
                                            episode: item.episode,
                                            podcastTitle: item.podcastTitle,
                                            podcastImage: item.podcastImage
                                        )
                                    }
                                }
                            }

                            if isLoadingRecent {
                                ProgressView()
                                    .tint(Color.appAccent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, AppSpacing.md)
                            }
                        }
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.top, AppSpacing.lg)
                        .padding(.bottom, 100)
                    }
                } else if isLoadingRecent {
                    Spacer()
                    ProgressView()
                        .tint(Color.appAccent)
                    Spacer()
                } else {
                    Spacer()

                    VStack(spacing: AppSpacing.lg) {
                        Image("LaunchLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 48)
                            .opacity(0.4)

                        VStack(spacing: AppSpacing.sm) {
                            Text("Finn din neste favoritt")
                                .font(.bodyText)
                                .foregroundStyle(Color.appMutedForeground)

                            Text("Prøv å søke etter NRK, Aftenpodden\neller et tema du liker")
                                .font(.caption2Text)
                                .foregroundStyle(Color.appBorder)
                                .multilineTextAlignment(.center)
                        }
                    }

                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.sm) {
                        if searchVM.isLoading {
                            ProgressView()
                                .tint(Color.appAccent)
                                .padding(.top, AppSpacing.xxxl)
                        } else if let error = searchVM.error {
                            Text(error)
                                .font(.bodyText)
                                .foregroundStyle(Color.appError)
                                .padding(.top, AppSpacing.xxxl)
                        } else if searchVM.activeTab == .podcasts {
                            if searchVM.podcasts.isEmpty && !searchVM.filters.query.isEmpty {
                                NoResultsView()
                            } else {
                                ForEach(searchVM.podcasts) { podcast in
                                    NavigationLink(value: podcast) {
                                        PodcastCard(podcast: podcast)
                                    }
                                    .buttonStyle(CardButtonStyle())
                                }
                            }
                        } else {
                            if searchVM.episodes.isEmpty && !searchVM.filters.query.isEmpty {
                                NoResultsView()
                            } else {
                                ForEach(searchVM.episodes) { episodeWithPodcast in
                                    EpisodeCard(
                                        episode: episodeWithPodcast.episode,
                                        podcastTitle: episodeWithPodcast.podcastTitle,
                                        podcastImage: episodeWithPodcast.podcastImage
                                    )
                                }
                            }
                        }

                        // Attribution
                        Text("Søk via Podcast Index")
                            .font(.caption2Text)
                            .foregroundStyle(Color.appBorder)
                            .frame(maxWidth: .infinity)
                            .padding(.top, AppSpacing.md)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, 100)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showFilters) {
            FilterPanel()
        }
        .navigationDestination(for: Podcast.self) { podcast in
            PodcastDetailView(podcast: podcast)
        }
        .task {
            loadLastPlayed()
            await loadRecentEpisodes()
        }
    }

    // MARK: - Section Header

    @ViewBuilder
    private func homeSection<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appAccent)
                Text(title)
                    .font(.caption2Text)
                    .foregroundStyle(Color.appMutedForeground)
                    .textCase(.uppercase)
            }

            content()
        }
    }

    // MARK: - Data Loading

    private func loadLastPlayed() {
        lastPlayedInfo = LastPlayedInfo.load()
    }

    private func loadRecentEpisodes() async {
        let subs = subscriptionVM.subscriptions
        guard !subs.isEmpty else { return }

        isLoadingRecent = true
        defer { isLoadingRecent = false }

        let piSubs = subs.filter { !$0.podcastId.hasPrefix("nrk:") }
        let nrkSubs = subs.filter { $0.podcastId.hasPrefix("nrk:") }

        var results: [RecentEpisodeData] = []

        // Podcast Index subscriptions
        if !piSubs.isEmpty {
            let feedIds = piSubs.compactMap { Int($0.podcastId) }
            let since = Int(Date().timeIntervalSince1970) - 7 * 24 * 3600

            if !feedIds.isEmpty,
               let response = try? await PodcastIndexAPI.shared.episodesByFeedIds(feedIds, max: 50, since: since) {
                let subMap = Dictionary(uniqueKeysWithValues: piSubs.map { ($0.podcastId, $0) })
                for piEpisode in response.items ?? [] {
                    let episode = PodcastTransform.transformEpisode(piEpisode)
                    if let sub = subMap[episode.podcastId] {
                        results.append(RecentEpisodeData(
                            episode: episode,
                            podcastTitle: sub.title,
                            podcastImage: sub.imageUrl
                        ))
                    }
                }
            }
        }

        // NRK subscriptions
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        let formatter = ISO8601DateFormatter()

        for sub in nrkSubs {
            let slug = String(sub.podcastId.dropFirst(4))
            if let result = try? await NRKPodcastService.shared.fetchEpisodes(nrkSlug: slug) {
                for ep in result.episodes {
                    if let date = formatter.date(from: ep.publishedAt), date > sevenDaysAgo {
                        results.append(RecentEpisodeData(
                            episode: ep,
                            podcastTitle: result.podcastTitle,
                            podcastImage: result.podcastImageUrl
                        ))
                    }
                }
            }
        }

        // Sort newest first (ISO8601 strings sort lexicographically)
        results.sort { $0.episode.publishedAt > $1.episode.publishedAt }

        recentEpisodes = Array(results.prefix(20))
    }
}

// MARK: - Supporting Types

private struct RecentEpisodeData: Identifiable {
    var id: String { episode.id }
    let episode: Episode
    let podcastTitle: String
    let podcastImage: String
}

// MARK: - No Results

private struct NoResultsView: View {
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.appBorder)

            Text("Ingen resultater")
                .font(.bodyText)
                .foregroundStyle(Color.appMutedForeground)
        }
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
#Preview("Søkeresultater") {
    PreviewWrapper(searchResults: true) {
        NavigationStack {
            HomeView()
        }
    }
}

#Preview("Oppdaging") {
    PreviewWrapper {
        NavigationStack {
            HomeView()
        }
    }
}
#endif
