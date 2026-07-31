import Foundation

extension SearchViewModel {

    // MARK: - Episode Search

    func searchEpisodes(_ query: String) async {
        isLoading = true
        error = nil

        let api = self.api

        let parsed = SearchQueryParser.parse(query)
        let apiQueries = buildApiQueries(from: parsed)
        guard let primaryQuery = apiQueries.first else {
            isLoading = false
            return
        }

        do {
            var allEpisodes: [EpisodeWithPodcast] = []
            var existingIds = Set<String>()

            let hasCategory = !filters.categories.isEmpty

            // Source podcasts for strategy 2, always derived from the query
            // being searched right now. This previously reused `self.podcasts`,
            // which still held whatever the Podcasts tab last searched for, so
            // changing the query on the Episodes tab returned episodes drawn
            // from the previous query's podcasts.
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

                        // Episodes come back per feed, not per query, so the
                        // operators have to be enforced here. Word-boundary
                        // matching, same as applyQueryOperators.
                        let text = "\(ep.title) \(ep.description)".lowercased()
                        let hasAllRequired = parsed.mustInclude
                            .filter { $0.count >= 2 }
                            .allSatisfy { SearchQueryParser.containsTerm($0.lowercased(), in: text) }
                        let hasAnyShouldInclude = parsed.shouldInclude.isEmpty || parsed.shouldInclude.contains {
                            SearchQueryParser.containsTerm($0.lowercased(), in: text)
                        }
                        let hasAllPhrases = parsed.exactPhrases.allSatisfy {
                            SearchQueryParser.containsTerm($0.lowercased(), in: text)
                        }
                        guard hasAllRequired && hasAnyShouldInclude && hasAllPhrases else { continue }

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
                break
            }

            episodes = allEpisodes

        } catch {
            if !Task.isCancelled {
                self.error = "Episodesøket feilet. Prøv igjen."
            }
        }

        if !Task.isCancelled {
            isLoading = false
        }
    }
}
