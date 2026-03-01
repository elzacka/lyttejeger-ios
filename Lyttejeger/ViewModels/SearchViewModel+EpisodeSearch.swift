import Foundation

extension SearchViewModel {

    // MARK: - Episode Search

    func searchEpisodes(_ query: String) async {
        isLoading = true
        error = nil

        let api = PodcastIndexAPI.shared

        let parsed = SearchQueryParser.parse(query)
        guard let apiQuery = buildApiQuery(from: parsed) else {
            isLoading = false
            return
        }

        do {
            var allEpisodes: [EpisodeWithPodcast] = []
            var existingIds = Set<String>()

            // When categories active, find matching podcasts for episode filtering
            let hasCategory = !filters.categories.isEmpty
            var categoryMatchedPodcasts: [Podcast]?
            if hasCategory {
                var catOptions = SearchOptions()
                catOptions.max = AppConstants.searchResultsWithCategory
                catOptions.fulltext = true
                catOptions.lang = getApiLanguageCodes(filters.languages) ?? AppConstants.allowedLanguagesAPI
                catOptions.cat = filters.categories.joined(separator: ",")
                if let termRes = try? await api.searchByTerm(apiQuery, options: catOptions) {
                    var results = PodcastTransform.transformFeeds(termRes.feeds ?? [])
                    results = filterByCategory(results)
                    results = filterByLanguage(results)
                    categoryMatchedPodcasts = results
                }
                guard !Task.isCancelled else { return }
            }
            let categoryFeedIds: Set<String>? = categoryMatchedPodcasts.map { Set($0.map(\.id)) }

            // Strategy 1: byperson search
            let personRes = try await api.searchByPerson(apiQuery, max: 50)
            let personEps = PodcastTransform.transformEpisodes(personRes.items ?? [])
            for (idx, ep) in personEps.enumerated() {
                guard !existingIds.contains(ep.id) else { continue }
                let apiEp = personRes.items?[idx]

                // Category filter: only include episodes from matching feeds
                if let feedIds = categoryFeedIds {
                    guard let feedId = apiEp?.feedId,
                          feedIds.contains(String(feedId)) else { continue }
                }

                let feedLang = apiEp?.feedLanguage ?? ""
                if !filters.languages.isEmpty {
                    guard filters.languages.contains(where: { matchesLanguageFilter(feedLang, filterLabel: $0) }) else { continue }
                } else {
                    guard isAllowedLanguage(feedLang) else { continue }
                }

                allEpisodes.append(EpisodeWithPodcast(
                    episode: ep,
                    podcast: nil,
                    podcastTitle: apiEp?.feedTitle ?? "",
                    podcastAuthor: apiEp?.feedAuthor ?? "",
                    podcastImage: apiEp?.feedImage ?? "",
                    feedLanguage: feedLang
                ))
                existingIds.insert(ep.id)
            }

            guard !Task.isCancelled else { return }

            // Strategy 2: episodes from matching podcasts
            let episodeSourcePodcasts = categoryMatchedPodcasts ?? Array(podcasts.prefix(AppConstants.episodeSearchPodcastLimit))
            if !episodeSourcePodcasts.isEmpty {
                let topPodcasts = Array(episodeSourcePodcasts.prefix(AppConstants.episodeSearchPodcastLimit))
                let feedIds = topPodcasts.compactMap { Int($0.id) }
                let podcastMap = Dictionary(uniqueKeysWithValues: topPodcasts.map { ($0.id, $0) })

                if let epsRes = try? await api.episodesByFeedIds(feedIds, max: 200) {
                    let eps = PodcastTransform.transformEpisodes(epsRes.items ?? [])
                    for (idx, ep) in eps.enumerated() {
                        guard !existingIds.contains(ep.id) else { continue }
                        let apiEp = epsRes.items?[idx]
                        let podcast = podcastMap[String(apiEp?.feedId ?? 0)]

                        let text = "\(ep.title) \(ep.description)".lowercased()
                        let hasAllRequired = parsed.mustInclude.filter { $0.count >= 2 }.allSatisfy { text.contains($0.lowercased()) }
                        let hasAnyShouldInclude = parsed.shouldInclude.isEmpty || parsed.shouldInclude.contains { text.contains($0.lowercased()) }
                        let hasAllPhrases = parsed.exactPhrases.allSatisfy { text.contains($0.lowercased()) }
                        guard hasAllRequired && hasAnyShouldInclude && hasAllPhrases else { continue }

                        allEpisodes.append(EpisodeWithPodcast(
                            episode: ep,
                            podcast: podcast,
                            podcastTitle: podcast?.title ?? apiEp?.feedTitle ?? "",
                            podcastAuthor: podcast?.author ?? apiEp?.feedAuthor ?? "",
                            podcastImage: podcast?.imageUrl ?? apiEp?.feedImage ?? "",
                            feedLanguage: podcast?.language ?? apiEp?.feedLanguage ?? ""
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
