import Foundation

extension SearchViewModel {

    // MARK: - Podcast Search

    func searchPodcasts(_ query: String) async {
        isLoading = true
        error = nil

        let api = PodcastIndexAPI.shared

        do {
            let parsed = SearchQueryParser.parse(query)
            guard let apiQuery = buildApiQuery(from: parsed) else {
                isLoading = false
                return
            }

            let hasCategory = !filters.categories.isEmpty

            var options = SearchOptions()
            options.max = hasCategory ? AppConstants.searchResultsWithCategory : AppConstants.searchResultsDefault
            options.fulltext = true
            options.lang = getApiLanguageCodes(filters.languages) ?? AppConstants.allowedLanguagesAPI
            if hasCategory { options.cat = filters.categories.joined(separator: ",") }

            // Hybrid: title search + term search, deduplicated
            var allFeeds: [PodcastIndexFeed] = []
            var seenIds = Set<Int>()

            // Title search first
            if let titleRes = try? await api.searchByTitle(apiQuery, options: SearchOptions(max: 50, fulltext: true, lang: options.lang)) {
                for feed in titleRes.feeds ?? [] {
                    if seenIds.insert(feed.id).inserted {
                        allFeeds.append(feed)
                    }
                }
            }

            guard !Task.isCancelled else { return }

            // Term search
            let termRes = try await api.searchByTerm(apiQuery, options: options)
            for feed in termRes.feeds ?? [] {
                if seenIds.insert(feed.id).inserted {
                    allFeeds.append(feed)
                }
            }

            guard !Task.isCancelled else { return }

            var results = PodcastTransform.transformFeeds(allFeeds)
            results = filterByLanguage(results)
            results = filterByCategory(results)

            // Apply query operators (exclude, exact phrase, OR)
            results = applyQueryOperators(results, parsed: parsed)

            // Composite ranking
            results = rankResults(results, query: apiQuery, parsed: parsed)

            // Apply local filters (date, sort override)
            results = applyLocalFilters(results)

            // Merge NRK results (local, instant)
            let nrkResults = await NRKPodcastService.shared.searchCatalog(query: apiQuery)
            if !nrkResults.isEmpty {
                let piTitles = Set(results.map { $0.title.lowercased() })
                var unique = nrkResults.filter { !piTitles.contains($0.title.lowercased()) }
                unique = applyQueryOperators(unique, parsed: parsed)
                results.append(contentsOf: unique)
            }

            podcasts = results

        } catch {
            if !Task.isCancelled {
                self.error = "Søket feilet. Prøv igjen."
            }
        }

        if !Task.isCancelled {
            isLoading = false
        }
    }

    // MARK: - API Query Builder

    func buildApiQuery(from parsed: ParsedQuery) -> String? {
        var parts: [String] = []

        for phrase in parsed.exactPhrases {
            parts.append("\"\(phrase)\"")
        }
        parts.append(contentsOf: parsed.mustInclude.filter { $0.count >= 2 })
        parts.append(contentsOf: parsed.shouldInclude.filter { $0.count >= 2 })

        // No positive terms → nothing useful to search for
        guard !parts.isEmpty else { return nil }

        // Exclude terms are NOT sent to API — Podcast Index doesn't support
        // them and treats "-term" as a literal search string, causing zero results.
        // Exclusions are enforced client-side in applyQueryOperators().

        return parts.joined(separator: " ")
    }

    // MARK: - Query Operator Enforcement

    func matchesQueryOperators(_ text: String, parsed: ParsedQuery) -> Bool {
        for term in parsed.mustExclude where term.count >= 2 {
            if text.contains(term.lowercased()) { return false }
        }
        for phrase in parsed.exactPhrases {
            if !text.contains(phrase.lowercased()) { return false }
        }
        if !parsed.shouldInclude.isEmpty {
            if !parsed.shouldInclude.contains(where: { text.contains($0.lowercased()) }) { return false }
        }
        return true
    }

    func applyQueryOperators(_ results: [Podcast], parsed: ParsedQuery) -> [Podcast] {
        guard !parsed.mustExclude.isEmpty || !parsed.exactPhrases.isEmpty || !parsed.shouldInclude.isEmpty else {
            return results
        }
        return results.filter { matchesQueryOperators("\($0.title) \($0.description) \($0.author)".lowercased(), parsed: parsed) }
    }

    func applyQueryOperators(_ results: [EpisodeWithPodcast], parsed: ParsedQuery) -> [EpisodeWithPodcast] {
        guard !parsed.mustExclude.isEmpty || !parsed.exactPhrases.isEmpty || !parsed.shouldInclude.isEmpty else {
            return results
        }
        return results.filter { matchesQueryOperators("\($0.episode.title) \($0.episode.description) \($0.podcastTitle)".lowercased(), parsed: parsed) }
    }

    // MARK: - Shared Filters

    func filterByLanguage(_ podcasts: [Podcast]) -> [Podcast] {
        if !filters.languages.isEmpty {
            podcasts.filter { p in filters.languages.contains { matchesLanguageFilter(p.language, filterLabel: $0) } }
        } else {
            podcasts.filter { isAllowedLanguage($0.language) }
        }
    }

    func filterByCategory(_ podcasts: [Podcast]) -> [Podcast] {
        guard !filters.categories.isEmpty else { return podcasts }
        let lowerFilters = filters.categories.map { $0.lowercased() }
        return podcasts.filter { p in
            p.categories.contains { cat in
                let lowerCat = cat.lowercased()
                return lowerFilters.contains { lowerCat.contains($0) || $0.contains(lowerCat) }
            }
        }
    }

    // MARK: - Composite Ranking

    func rankResults(_ podcasts: [Podcast], query: String, parsed: ParsedQuery) -> [Podcast] {
        let queryLower = query.lowercased()
        let terms = (parsed.mustInclude + parsed.shouldInclude + parsed.exactPhrases).map { $0.lowercased() }
        let now = Date()
        let daySeconds: TimeInterval = 86400

        let scored = podcasts.map { podcast -> (Podcast, Double) in
            var score: Double = 0
            let titleLower = podcast.title.lowercased()
            let authorLower = podcast.author.lowercased()

            // Title match (highest weight)
            if titleLower == queryLower {
                score += 100
            } else if titleLower.hasPrefix(queryLower) {
                score += 80
            } else if titleLower.contains(queryLower) {
                score += 60
            }

            // Individual term matches in title
            for term in terms where titleLower.contains(term) {
                score += 20
            }

            // Author match
            if authorLower.contains(queryLower) {
                score += 15
            }

            // Freshness signal
            let lastUpdated = iso8601BasicFormatter.date(from: podcast.lastUpdated) ?? .distantPast
            let daysSinceUpdate = now.timeIntervalSince(lastUpdated) / daySeconds
            if daysSinceUpdate < 7 {
                score += 15
            } else if daysSinceUpdate < 30 {
                score += 10
            } else if daysSinceUpdate < 180 {
                score += 5
            } else if daysSinceUpdate > 365 {
                score -= 5
            }

            // Popularity bonus
            if podcast.episodeCount > 100 {
                score += 5
            } else if podcast.episodeCount > 20 {
                score += 3
            }

            // Dead feed penalty
            if podcast.episodeCount == 0 {
                score -= 10
            }

            return (podcast, score)
        }

        return scored
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }
}
