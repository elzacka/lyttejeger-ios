import Foundation

extension SearchViewModel {

    // MARK: - Episode Search

    func searchEpisodes(_ query: String) async {
        error = nil

        let api = self.api

        let parsed = SearchQueryParser.parse(query)
        let apiQueries = buildApiQueries(from: parsed)
        guard let primaryQuery = apiQueries.first else { return }

        do {
            var allEpisodes: [EpisodeWithPodcast] = []
            var existingIds = Set<String>()

            let hasCategory = !filters.categories.isEmpty

            // Source podcasts for strategy 2, always derived from the query
            // being searched right now. This previously reused `self.podcasts`,
            // which still held whatever the Podcasts tab last searched for, so
            // changing the query on the Episodes tab returned episodes drawn
            // from the previous query's podcasts.
            // Deliberately without `similar`, unlike the podcast search: this
            // list is truncated to episodeSearchPodcastLimit before episodes
            // are fetched, so looser matches would push good feeds out of the
            // window instead of just sorting below them.
            var sourceOptions = SearchOptions()
            sourceOptions.max = hasCategory ? AppConstants.searchResultsWithCategory : AppConstants.searchResultsDefault
            sourceOptions.fulltext = true

            var sourcePodcasts: [Podcast] = []
            var seenFeedIds = Set<String>()
            for apiQuery in apiQueries {
                if let termRes = try? await api.searchByTerm(apiQuery, options: sourceOptions) {
                    var branch = PodcastTransform.transformFeeds(termRes.feeds ?? [])
                    branch = filterByCategory(branch)
                    branch = filterByLanguage(branch)
                    for podcast in branch where seenFeedIds.insert(podcast.id).inserted {
                        sourcePodcasts.append(podcast)
                    }
                }
                guard !Task.isCancelled else { return }
            }

            // Only constrain byperson hits to these feeds when the user picked
            // a category; otherwise byperson should stay as broad as it is.
            let categoryFeedIds: Set<String>? = hasCategory ? seenFeedIds : nil

            // Strategy 1: byperson search
            // zip keeps each transformed episode paired with its API item even
            // if the transform ever starts filtering
            let personRes = try await api.searchByPerson(primaryQuery, max: 50)
            let personEps = PodcastTransform.transformEpisodes(personRes.items ?? [])
            for (ep, apiEp) in zip(personEps, personRes.items ?? []) {
                guard !existingIds.contains(ep.id) else { continue }

                // Category filter: only include episodes from matching feeds
                if let feedIds = categoryFeedIds {
                    guard let feedId = apiEp.feedId,
                          feedIds.contains(String(feedId)) else { continue }
                }

                let feedLang = apiEp.feedLanguage ?? ""
                if !filters.languages.isEmpty {
                    guard filters.languages.contains(where: { matchesLanguageFilter(feedLang, filterLabel: $0) }) else { continue }
                } else {
                    guard isAllowedLanguage(feedLang) else { continue }
                }

                allEpisodes.append(EpisodeWithPodcast(
                    episode: ep,
                    podcast: nil,
                    podcastTitle: apiEp.feedTitle ?? "",
                    podcastAuthor: apiEp.feedAuthor ?? "",
                    podcastImage: apiEp.feedImage ?? "",
                    feedLanguage: feedLang
                ))
                existingIds.insert(ep.id)
            }

            guard !Task.isCancelled else { return }

            // Strategy 2: episodes from matching podcasts
            if !sourcePodcasts.isEmpty {
                let topPodcasts = Array(sourcePodcasts.prefix(AppConstants.episodeSearchPodcastLimit))
                let feedIds = topPodcasts.compactMap { Int($0.id) }
                let podcastMap = Dictionary(uniqueKeysWithValues: topPodcasts.map { ($0.id, $0) })

                if let epsRes = try? await api.episodesByFeedIds(feedIds, max: 200, since: nil) {
                    let eps = PodcastTransform.transformEpisodes(epsRes.items ?? [])
                    for (ep, apiEp) in zip(eps, epsRes.items ?? []) {
                        guard !existingIds.contains(ep.id) else { continue }
                        let podcast = podcastMap[String(apiEp.feedId ?? 0)]

                        guard episodeMatchesQuery(ep, parsed: parsed) else { continue }

                        allEpisodes.append(EpisodeWithPodcast(
                            episode: ep,
                            podcast: podcast,
                            podcastTitle: podcast?.title ?? apiEp.feedTitle ?? "",
                            podcastAuthor: podcast?.author ?? apiEp.feedAuthor ?? "",
                            podcastImage: podcast?.imageUrl ?? apiEp.feedImage ?? "",
                            feedLanguage: podcast?.language ?? apiEp.feedLanguage ?? ""
                        ))
                        existingIds.insert(ep.id)
                    }
                }
            }

            // Strategy 3: NRK episodes.
            // NRK is absent from Podcast Index episode data, so without this
            // the Episodes tab could never surface an NRK episode even though
            // the Podcasts tab finds the show. Catalog failure is not fatal:
            // Podcast Index episodes still show, with a notice.
            do {
                var nrkPodcasts: [Podcast] = []
                var seenNrkIds = Set<String>()
                for apiQuery in apiQueries {
                    for match in try await nrkService.searchCatalog(query: apiQuery)
                    where seenNrkIds.insert(match.id).inserted {
                        nrkPodcasts.append(match)
                    }
                }

                // Capped at the same number as the existing NRK concurrency
                // limit, so every feed can be fetched in one parallel round.
                let targets = nrkPodcasts
                    .prefix(AppConstants.nrkConcurrencyLimit)
                    .compactMap { podcast -> (slug: String, podcast: Podcast)? in
                        podcast.nrkSlug.map { (slug: $0, podcast: podcast) }
                    }

                if !targets.isEmpty {
                    let nrkService = self.nrkService
                    let fetched = await withTaskGroup(of: (Podcast, NRKFeedResult)?.self) { group in
                        for target in targets {
                            group.addTask {
                                guard let feed = try? await nrkService.fetchEpisodes(nrkSlug: target.slug) else {
                                    return nil
                                }
                                return (target.podcast, feed)
                            }
                        }
                        var collected: [(Podcast, NRKFeedResult)] = []
                        for await result in group {
                            if let result { collected.append(result) }
                        }
                        return collected
                    }

                    // Same text filter as strategy 2: a matching show is not
                    // reason enough to list all of its episodes.
                    for (podcast, feed) in fetched {
                        for ep in feed.episodes
                        where !existingIds.contains(ep.id) && episodeMatchesQuery(ep, parsed: parsed) {
                            allEpisodes.append(EpisodeWithPodcast(
                                episode: ep,
                                podcast: podcast,
                                podcastTitle: feed.podcastTitle,
                                podcastAuthor: podcast.author,
                                podcastImage: feed.podcastImageUrl,
                                feedLanguage: podcast.language
                            ))
                            existingIds.insert(ep.id)
                        }
                    }
                }
            } catch {
                nrkUnavailable = true
            }

            guard !Task.isCancelled else { return }

            // Apply query operators (exclude, exact phrase, OR)
            allEpisodes = applyQueryOperators(allEpisodes, parsed: parsed)

            // Apply duration filter
            if let durationFilter = filters.durationFilter {
                allEpisodes = allEpisodes.filter { durationFilter.matches(duration: $0.episode.duration) }
            }

            // Apply date filter
            if let dateFrom = filters.dateFrom {
                let fromDate = dateFrom.date
                allEpisodes = allEpisodes.filter {
                    (iso8601BasicFormatter.date(from: $0.episode.publishedAt) ?? .distantPast) >= fromDate
                }
            }
            if let dateTo = filters.dateTo {
                let toDate = dateTo.date
                allEpisodes = allEpisodes.filter {
                    (iso8601BasicFormatter.date(from: $0.episode.publishedAt) ?? .distantFuture) <= toDate
                }
            }

            // Sort
            switch filters.sortBy {
            case .newest:
                allEpisodes.sort { a, b in
                    let dateA = iso8601BasicFormatter.date(from: a.episode.publishedAt) ?? .distantPast
                    let dateB = iso8601BasicFormatter.date(from: b.episode.publishedAt) ?? .distantPast
                    return dateA > dateB
                }
            case .oldest:
                allEpisodes.sort { a, b in
                    let dateA = iso8601BasicFormatter.date(from: a.episode.publishedAt) ?? .distantPast
                    let dateB = iso8601BasicFormatter.date(from: b.episode.publishedAt) ?? .distantPast
                    return dateA < dateB
                }
            case .popular:
                allEpisodes.sort { a, b in
                    let countA = a.podcast?.episodeCount ?? 0
                    let countB = b.podcast?.episodeCount ?? 0
                    return countA > countB
                }
            case .relevance:
                allEpisodes = rankEpisodes(allEpisodes, query: primaryQuery, parsed: parsed)
            }

            episodes = allEpisodes

        } catch {
            if !Task.isCancelled {
                self.error = "Episodesøket feilet. Prøv igjen."
            }
        }
    }

    // MARK: - Episode Matching

    /// Whether an episode satisfies the query terms on its own text.
    ///
    /// Episodes fetched per feed (strategy 2 and the NRK strategy) arrive
    /// because their *show* matched, not because they did, so the terms have
    /// to be checked here. Word-boundary matching, same as
    /// `matchesQueryOperators`. Exclusions are handled later by
    /// `applyQueryOperators`, which also sees the podcast title.
    func episodeMatchesQuery(_ episode: Episode, parsed: ParsedQuery) -> Bool {
        let text = "\(episode.title) \(episode.description)".lowercased()

        let hasAllRequired = parsed.mustInclude
            .filter { $0.count >= 2 }
            .allSatisfy { SearchQueryParser.containsTerm($0.lowercased(), in: text) }
        let hasAnyShouldInclude = parsed.shouldInclude.isEmpty || parsed.shouldInclude.contains {
            SearchQueryParser.containsTerm($0.lowercased(), in: text)
        }
        let hasAllPhrases = parsed.exactPhrases.allSatisfy {
            SearchQueryParser.containsTerm($0.lowercased(), in: text)
        }

        return hasAllRequired && hasAnyShouldInclude && hasAllPhrases
    }

    // MARK: - Episode Ranking

    /// Scores episodes for the "Relevans" sort.
    ///
    /// Episodes arrive from two unrelated strategies (a person search and a
    /// per-feed episode dump), so without this the default sort was simply the
    /// order they happened to be appended in. Mirrors `rankResults` for
    /// podcasts: the episode's own title counts most, the podcast title is a
    /// weaker signal, description matches count least, and recency breaks ties.
    func rankEpisodes(_ episodes: [EpisodeWithPodcast], query: String, parsed: ParsedQuery) -> [EpisodeWithPodcast] {
        let queryLower = query.lowercased()
        let terms = (parsed.mustInclude + parsed.shouldInclude + parsed.exactPhrases).map { $0.lowercased() }
        let now = Date()
        let daySeconds: TimeInterval = 86400

        let scored = episodes.map { item -> (EpisodeWithPodcast, Double) in
            var score: Double = 0
            let titleLower = item.episode.title.lowercased()

            if titleLower == queryLower {
                score += 100
            } else if titleLower.hasPrefix(queryLower) {
                score += 80
            } else if SearchQueryParser.containsTerm(queryLower, in: titleLower) {
                score += 60
            }

            for term in terms where SearchQueryParser.containsTerm(term, in: titleLower) {
                score += 20
            }

            // Matching the podcast rather than the episode is a real signal,
            // but a weaker one: every episode of that podcast matches equally.
            if SearchQueryParser.containsTerm(queryLower, in: item.podcastTitle.lowercased()) {
                score += 15
            }

            let descriptionLower = item.episode.description.lowercased()
            for term in terms where SearchQueryParser.containsTerm(term, in: descriptionLower) {
                score += 5
            }

            let published = iso8601BasicFormatter.date(from: item.episode.publishedAt) ?? .distantPast
            let daysSincePublished = now.timeIntervalSince(published) / daySeconds
            if daysSincePublished < 7 {
                score += 15
            } else if daysSincePublished < 30 {
                score += 10
            } else if daysSincePublished < 180 {
                score += 5
            } else if daysSincePublished > 365 {
                score -= 5
            }

            return (item, score)
        }

        return scored
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }
}
