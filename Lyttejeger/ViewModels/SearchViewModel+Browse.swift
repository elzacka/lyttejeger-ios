import Foundation

extension SearchViewModel {

    // MARK: - Browse

    /// Filters without a query. Each tab browses its own kind of content, so
    /// the Episodes tab is no longer left blank when only filters are set.
    func browse() async {
        if activeTab == .episodes {
            await browseEpisodes()
        } else {
            await browsePodcasts()
        }
    }

    func browsePodcasts() async {
        error = nil

        do {
            podcasts = applyLocalFilters(try await trendingPodcasts())
            episodes = []
        } catch {
            if !Task.isCancelled {
                self.error = "Kunne ikke hente innhold. Prøv igjen."
            }
        }
    }

    /// Trending feeds narrowed by the active filters.
    ///
    /// `cat` is sent as a hint because it improves what the endpoint returns,
    /// but it is never trusted: trending happily returns feeds outside the
    /// requested category, and a value it dislikes makes it answer 500 instead
    /// of an empty list. So the category narrowing is always redone locally,
    /// and a rejected `cat` costs a second request rather than the whole
    /// browse. Retries are already off for this case in `trending`.
    private func trendingPodcasts() async throws -> [Podcast] {
        let api = self.api
        let lang = getApiLanguageCodes(filters.languages)
        let hasCategory = !filters.categories.isEmpty
        let cat = hasCategory ? filters.categories.joined(separator: ",") : nil

        let res: SearchResponse
        do {
            res = try await api.trending(
                max: hasCategory ? AppConstants.browseResultsWithCategory : AppConstants.browseResultsDefault,
                lang: lang,
                cat: cat,
                notcat: nil
            )
        } catch {
            guard cat != nil, !Task.isCancelled else { throw error }
            res = try await api.trending(
                max: AppConstants.browseResultsWithCategory,
                lang: lang,
                cat: nil,
                notcat: nil
            )
        }

        var results = PodcastTransform.transformFeeds(res.feeds ?? [])
        results = filterByLanguage(results)
        results = filterByCategory(results)
        return results
    }

    // MARK: - Episode Browse

    func browseEpisodes() async {
        error = nil

        let api = self.api

        do {
            var results: [EpisodeWithPodcast]

            if filters.categories.isEmpty {
                // Nothing to narrow by feed, so the recent-episodes endpoint is
                // both broader and one request instead of two.
                let res = try await api.recentEpisodes(
                    max: AppConstants.browseResultsDefault,
                    lang: getApiLanguageCodes(filters.languages)
                )
                results = episodesWithFeedMetadata(res.items ?? [], podcastsById: [:])
            } else {
                // A category lives on the feed, never on the episode, so the
                // matching feeds have to be resolved before their episodes can
                // be pulled.
                // Trending can repeat a feed; a duplicate id would trap in
                // Dictionary(uniqueKeysWithValues:) below and be requested twice.
                var seenFeedIds = Set<String>()
                let feeds = Array(
                    try await trendingPodcasts()
                        .filter { seenFeedIds.insert($0.id).inserted }
                        .prefix(AppConstants.episodeSearchPodcastLimit)
                )
                guard !feeds.isEmpty else {
                    episodes = []
                    podcasts = []
                    return
                }
                guard !Task.isCancelled else { return }

                let podcastsById = Dictionary(uniqueKeysWithValues: feeds.map { ($0.id, $0) })
                let res = try await api.episodesByFeedIds(
                    feeds.compactMap { Int($0.id) },
                    max: AppConstants.browseResultsDefault,
                    since: nil
                )
                results = episodesWithFeedMetadata(res.items ?? [], podcastsById: podcastsById)
            }

            results = filterEpisodesByLanguage(results)
            episodes = applyEpisodeFilters(results)
            podcasts = []

        } catch {
            if !Task.isCancelled {
                self.error = "Kunne ikke hente episoder. Prøv igjen."
            }
        }
    }

    /// Pairs API episodes with the feed they came from, preferring the richer
    /// `Podcast` record when the caller already resolved it.
    func episodesWithFeedMetadata(
        _ items: [PodcastIndexEpisode],
        podcastsById: [String: Podcast]
    ) -> [EpisodeWithPodcast] {
        var seen = Set<String>()
        var results: [EpisodeWithPodcast] = []

        for (episode, item) in zip(PodcastTransform.transformEpisodes(items), items) {
            guard seen.insert(episodeDedupeKey(episode)).inserted else { continue }
            let podcast = item.feedId.flatMap { podcastsById[String($0)] }
            results.append(EpisodeWithPodcast(
                episode: episode,
                podcast: podcast,
                podcastTitle: podcast?.title ?? item.feedTitle ?? "",
                podcastAuthor: podcast?.author ?? item.feedAuthor ?? "",
                podcastImage: podcast?.imageUrl ?? item.feedImage ?? "",
                feedLanguage: podcast?.language ?? item.feedLanguage ?? ""
            ))
        }

        return results
    }

    /// Applies the language filter to episodes, using the same rules and the
    /// same default allow-list as the podcast filter.
    func filterEpisodesByLanguage(_ episodes: [EpisodeWithPodcast]) -> [EpisodeWithPodcast] {
        if !filters.languages.isEmpty {
            episodes.filter { item in
                filters.languages.contains { matchesLanguageFilter(item.feedLanguage, filterLabel: $0) }
            }
        } else {
            episodes.filter { isAllowedLanguage($0.feedLanguage) }
        }
    }

    // MARK: - Local Filters

    func applyLocalFilters(_ podcasts: [Podcast]) -> [Podcast] {
        var filtered = podcasts

        if let dateFrom = filters.dateFrom {
            let fromDate = dateFrom.date
            filtered = filtered.filter {
                (iso8601BasicFormatter.date(from: $0.lastUpdated) ?? .distantPast) >= fromDate
            }
        }

        if let dateTo = filters.dateTo {
            let toDate = dateTo.date
            filtered = filtered.filter {
                (iso8601BasicFormatter.date(from: $0.lastUpdated) ?? .distantFuture) <= toDate
            }
        }

        switch filters.sortBy {
        case .newest:
            filtered.sort { $0.lastUpdated > $1.lastUpdated }
        case .oldest:
            filtered.sort { $0.lastUpdated < $1.lastUpdated }
        case .popular:
            filtered.sort { $0.episodeCount > $1.episodeCount }
        case .relevance:
            break
        }

        return filtered
    }

    func isAllowedLanguage(_ lang: String) -> Bool {
        allLanguages.contains { matchesLanguageFilter(lang, filterLabel: $0) }
    }
}
