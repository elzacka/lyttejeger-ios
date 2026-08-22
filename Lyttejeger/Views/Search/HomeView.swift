import SwiftUI

struct HomeView: View {
    @Environment(SearchViewModel.self) private var searchVM
    @Environment(SubscriptionViewModel.self) private var subscriptionVM
    @Environment(AudioPlayerViewModel.self) private var playerVM
    @Environment(QueueViewModel.self) private var queueVM
    @Environment(PlaybackProgressViewModel.self) private var progressVM
    @State private var showFilters = false
    @FocusState private var isSearchFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // Home sections
    @AppStorage(AppConstants.showLastPlayedKey) private var showLastPlayed = true
    @AppStorage(AppConstants.showNewFromSubscriptionsKey) private var showNewFromSubscriptions = true
    @State private var lastPlayedInfo: LastPlayedInfo?
    @State private var recentEpisodes: [RecentEpisodeData] = []
    @State private var hasLoadedRecent = false
    /// True when a home fetch failed, so an empty list is not passed off as
    /// "nothing new".
    @State private var recentEpisodesFailed = false

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

    /// Whether the user asked for anything at all — a query, a filter, or both.
    ///
    /// "Ingen resultater" used to require a non-empty query, so browsing with
    /// filters that matched nothing rendered an empty list with no explanation.
    private var hasSearchInput: Bool {
        !searchVM.filters.query.isEmpty || searchVM.hasActiveFilters
    }

    private var hasHomeContent: Bool {
        (showLastPlayed && lastPlayedEpisode != nil) || (showNewFromSubscriptions && !recentEpisodes.isEmpty)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            if isHomeState {
                homeContentView
                    .transition(.opacity)
            } else {
                searchResultsView
                    .transition(.opacity)
            }
        }
        .animation(
            UIAccessibility.isReduceMotionEnabled ? nil : .easeInOut(duration: 0.2),
            value: isHomeState
        )
        .animation(
            UIAccessibility.isReduceMotionEnabled ? nil : .easeInOut(duration: 0.2),
            value: searchVM.isLoading
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showFilters, onDismiss: { isSearchFocused = false }) {
            FilterPanel()
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.appBackground)
        }
        .navigationDestination(for: PodcastRoute.self) { route in
            PodcastDetailView(podcast: route.podcast, focusEpisodeId: route.focusEpisodeId)
        }
        .task(id: subscriptionVM.subscriptions.map(\.podcastId).sorted().joined(separator: ",")) {
            loadLastPlayed()
            hasLoadedRecent = false
            await loadRecentEpisodes()
        }
        .onChange(of: showNewFromSubscriptions) { _, newValue in
            if newValue {
                Task { await loadRecentEpisodes() }
            }
        }
        .onChange(of: playerVM.currentEpisode?.id) { _, _ in
            loadLastPlayed()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: AppSpacing.md) {
                // Decorative only — the field carries its own label. At
                // accessibility sizes it and the filter button left the
                // placeholder about three characters per line, so it broke
                // mid-word and truncated anyway.
                if !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.appAccent.opacity(0.7))
                        .font(.system(.callout))
                }

                // The system placeholder colour composites to about 1.7:1 on
                // the muted field, so the placeholder is drawn separately.
                ZStack(alignment: .leading) {
                    if searchVM.filters.query.isEmpty {
                        Text(searchVM.activeTab == .podcasts ? "Søk etter podkaster…" : "Søk etter episoder…")
                            .font(.bodyText)
                            .foregroundStyle(Color.appMutedForeground)
                            .allowsHitTesting(false)
                    }

                    TextField("", text: Binding(
                        get: { searchVM.filters.query },
                        set: { searchVM.setQuery($0) }
                    ))
                    .font(.bodyText)
                    .foregroundStyle(Color.appForeground)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .accessibilityLabel(searchVM.activeTab == .podcasts ? "Søk etter podkaster" : "Søk etter episoder")
                }

                if !searchVM.filters.query.isEmpty {
                    Button {
                        searchVM.setQuery("")
                        isSearchFocused = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(.subheadline))
                            .foregroundStyle(Color.appMutedForeground)
                            .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Tøm søkefeltet")
                }

                Button {
                    showFilters = true
                } label: {
                    Image(systemName: searchVM.activeFilterCount > 0
                        ? "line.3.horizontal.decrease.circle.fill"
                        : "line.3.horizontal.decrease.circle")
                        .font(.system(.callout))
                        .foregroundStyle(searchVM.activeFilterCount > 0 ? Color.appAccent : Color.appAccent.opacity(0.6))
                        .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(searchVM.activeFilterCount > 0 ? "Filter, \(searchVM.activeFilterCount) aktive" : "Filter")
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.md)
            .background(Color.appMuted)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .padding(.bottom, AppSpacing.md)

            // Tab switcher. Side by side each label gets half the width, which
            // at accessibility sizes broke "Podkaster" across two lines
            // mid-word and left the sliding indicator pointing at nothing.
            // Stacked, each label gets the full width and marks itself.
            let stacked = dynamicTypeSize.isAccessibilitySize
            let layout = stacked
                ? AnyLayout(VStackLayout(spacing: 0))
                : AnyLayout(HStackLayout(spacing: 0))

            layout {
                ForEach(SearchViewModel.SearchTab.allCases, id: \.self) { tab in
                    Button {
                        if UIAccessibility.isReduceMotionEnabled {
                            searchVM.setActiveTab(tab)
                        } else {
                            withAnimation(.easeOut(duration: 0.2)) {
                                searchVM.setActiveTab(tab)
                            }
                        }
                    } label: {
                        Text(tab == .podcasts ? "Podkaster" : "Episoder")
                            .font(.buttonText)
                            .foregroundStyle(searchVM.activeTab == tab ? Color.appAccent : Color.appMutedForeground)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: AppSize.touchTarget)
                            .contentShape(Rectangle())
                            .overlay(alignment: .bottom) {
                                if stacked && searchVM.activeTab == tab {
                                    Rectangle()
                                        .fill(Color.appAccent)
                                        .frame(height: 2)
                                }
                            }
                    }
                    .accessibilityAddTraits(searchVM.activeTab == tab ? .isSelected : [])
                }
            }
            .overlay(alignment: .bottom) {
                if !stacked {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.appAccent)
                            .frame(width: geo.size.width / 2, height: 2)
                            .offset(x: searchVM.activeTab == .podcasts ? 0 : geo.size.width / 2)
                            .animation(UIAccessibility.isReduceMotionEnabled ? nil : .easeOut(duration: 0.2), value: searchVM.activeTab)
                    }
                    .frame(height: 2)
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.xl)
    }

    // MARK: - Home Content

    @ViewBuilder
    private var homeContentView: some View {
        if hasHomeContent {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    if showLastPlayed, let last = lastPlayedEpisode {
                        homeSection("Fortsett", icon: "play.circle") {
                            EpisodeCard(
                                episode: last.episode,
                                podcastTitle: last.podcastTitle,
                                podcastImage: last.podcastImage,
                                usePodcastArtwork: true,
                                useDefaultContextMenu: false
                            )
                            .contextMenu {
                                lastPlayedContextMenu(episode: last.episode, podcastTitle: last.podcastTitle, podcastImage: last.podcastImage)
                            }
                        }
                    }

                    if showNewFromSubscriptions && !recentEpisodes.isEmpty {
                        homeSection("Nyeste", icon: "heart.fill") {
                            ForEach(recentEpisodes) { item in
                                EpisodeCard(
                                    episode: item.episode,
                                    podcastTitle: item.podcastTitle,
                                    podcastImage: item.podcastImage,
                                    usePodcastArtwork: true
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppConstants.playerBottomPadding)
            }
        } else if recentEpisodesFailed {
            Spacer()

            VStack(spacing: AppSpacing.md) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(.largeTitle, weight: .light))
                    .foregroundStyle(Color.appError)

                Text("Fikk ikke hentet nye episoder")
                    .font(.bodyText)
                    .foregroundStyle(Color.appMutedForeground)

                Text("Sjekk nettverkstilkoblingen og prøv igjen.")
                    .font(.caption2Text)
                    .foregroundStyle(Color.appMutedForeground)
                    .multilineTextAlignment(.center)

                Button {
                    Task {
                        hasLoadedRecent = false
                        recentEpisodesFailed = false
                        await loadRecentEpisodes()
                    }
                } label: {
                    Text("Prøv igjen")
                        .font(.buttonText)
                        .foregroundStyle(Color.appAccent)
                        .padding(.horizontal, AppSpacing.lg)
                        .frame(minHeight: AppSize.touchTarget)
                        .contentShape(Rectangle())
                }
            }

            Spacer()
        } else if !hasLoadedRecent && !subscriptionVM.subscriptions.isEmpty {
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

                Text("Finn din neste favoritt")
                    .font(.bodyText)
                    .foregroundStyle(Color.appMutedForeground)

                Text("Søk etter podkaster øverst på skjermen")
                    .font(.caption2Text)
                    .foregroundStyle(Color.appMutedForeground)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppSpacing.lg)

            Spacer()
        }
    }

    // MARK: - Search Results

    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.sm) {
                if searchVM.nrkUnavailable && !searchVM.isLoading {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.caption)
                        Text("Fikk ikke hentet NRK-katalogen. NRK-podkaster mangler i resultatene.")
                            .font(.caption2Text)
                    }
                    .foregroundStyle(Color.appMutedForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.sm)
                    .background(Color.appMuted)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                }

                if searchVM.isLoading {
                    ProgressView()
                        .tint(Color.appAccent)
                        .padding(.top, AppSpacing.xxxl)
                } else if let error = searchVM.error {
                    VStack(spacing: AppSpacing.md) {
                        Text(error)
                            .font(.bodyText)
                            .foregroundStyle(Color.appError)
                            .multilineTextAlignment(.center)

                        Button {
                            searchVM.retrySearch()
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
                    .padding(.top, AppSpacing.xxxl)
                } else if searchVM.activeTab == .podcasts {
                    if searchVM.podcasts.isEmpty && hasSearchInput {
                        NoResultsView(message: "Fant ingen podkaster")
                    } else {
                        ForEach(searchVM.podcasts) { podcast in
                            PodcastCard(podcast: podcast)
                        }
                    }
                } else {
                    if searchVM.episodes.isEmpty && hasSearchInput {
                        NoResultsView(message: "Fant ingen episoder")
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

                Text("Søk via Podcast Index")
                    .font(.caption2Text)
                    .foregroundStyle(Color.appMutedForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppSpacing.md)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppConstants.playerBottomPadding)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Section Header

    @ViewBuilder
    private func homeSection<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(Color.appAccent)
                Text(title)
                    .font(.sectionTitle)
                    .foregroundStyle(Color.appForeground)
            }

            content()
        }
    }

    // MARK: - Fortsett å lytte

    /// Long-press menu for the "Fortsett å lytte" card. Built by hand instead
    /// of the shared `episodeContextMenu` so it can add "Fjern", which does
    /// not apply to any other episode row.
    @ViewBuilder
    private func lastPlayedContextMenu(episode: Episode, podcastTitle: String, podcastImage: String) -> some View {
        Button {
            playerVM.play(episode: episode, podcastTitle: podcastTitle, podcastImage: podcastImage)
        } label: {
            Label("Spill", systemImage: "play.fill")
        }
        Button {
            queueVM.playNext(episode: episode, podcastTitle: podcastTitle, podcastImage: podcastImage)
        } label: {
            Label("Spill neste", systemImage: "text.insert")
        }
        Button {
            queueVM.addToQueue(episode: episode, podcastTitle: podcastTitle, podcastImage: podcastImage)
        } label: {
            Label("Legg i kø", systemImage: "text.append")
        }
        Button(role: .destructive) {
            removeLastPlayed(episodeId: episode.id)
        } label: {
            Label("Fjern fra Fortsett å lytte", systemImage: "xmark.circle")
        }
    }

    /// Clears both data sources `lastPlayedEpisode` can read from, and stops
    /// playback if the episode being removed is the one currently loaded —
    /// otherwise `playerVM.currentEpisode` would put the row straight back.
    private func removeLastPlayed(episodeId: String) {
        if playerVM.currentEpisode?.id == episodeId {
            playerVM.stop()
        }
        progressVM.clearProgress(for: episodeId)
        UserDefaults.standard.removeObject(forKey: AppConstants.lastPlayedInfoKey)
        lastPlayedInfo = nil
    }

    // MARK: - Data Loading

    private func loadLastPlayed() {
        lastPlayedInfo = LastPlayedInfo.load()
    }

    private func loadRecentEpisodes() async {
        let subs = subscriptionVM.subscriptions
        guard !subs.isEmpty else {
            hasLoadedRecent = true
            return
        }

        defer { hasLoadedRecent = true }
        var anyFetchFailed = false

        let piSubs = subs.filter { !$0.podcastId.hasPrefix("nrk:") }
        let nrkSubs = subs.filter { $0.podcastId.hasPrefix("nrk:") }

        var results: [RecentEpisodeData] = []

        // Podcast Index subscriptions
        if !piSubs.isEmpty {
            let feedIds = piSubs.compactMap { Int($0.podcastId) }
            let since = Int(Date().timeIntervalSince1970) - 7 * 24 * 3600

            let response = try? await PodcastIndexAPI.shared.episodesByFeedIds(feedIds, max: 50, since: since)
            if !feedIds.isEmpty, response == nil { anyFetchFailed = true }
            if !feedIds.isEmpty, let response {
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

        // NRK subscriptions (concurrent with limit)
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600)

        // Batch fetches to cap concurrency, same as BackgroundRefreshService
        let nrkSlugList = nrkSubs.map { String($0.podcastId.dropFirst(4)) }
        for batchStart in stride(from: 0, to: nrkSlugList.count, by: AppConstants.nrkConcurrencyLimit) {
            let batchSlugs = Array(nrkSlugList[batchStart..<min(batchStart + AppConstants.nrkConcurrencyLimit, nrkSlugList.count)])
            let batchResults = await withTaskGroup(of: [RecentEpisodeData].self) { group in
                for slug in batchSlugs {
                    group.addTask {
                        guard let result = try? await NRKPodcastService.shared.fetchEpisodes(nrkSlug: slug) else {
                            return []
                        }
                        return result.episodes.compactMap { ep in
                            guard let date = iso8601BasicFormatter.date(from: ep.publishedAt), date > sevenDaysAgo else { return nil }
                            return RecentEpisodeData(
                                episode: ep,
                                podcastTitle: result.podcastTitle,
                                podcastImage: result.podcastImageUrl
                            )
                        }
                    }
                }
                var collected: [RecentEpisodeData] = []
                for await batch in group {
                    collected.append(contentsOf: batch)
                }
                return collected
            }
            results.append(contentsOf: batchResults)
        }

        // Sort newest first (ISO8601 strings sort lexicographically)
        results.sort { $0.episode.publishedAt > $1.episode.publishedAt }

        recentEpisodes = Array(results.prefix(20))
        recentEpisodesFailed = anyFetchFailed && results.isEmpty
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
    /// Phrased for the active tab, so an episode search does not report
    /// missing podcasts.
    let message: String

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "magnifyingglass")
                .font(.system(.title, weight: .light))
                .foregroundStyle(Color.appMutedForeground)

            Text(message)
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
