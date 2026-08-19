import Foundation

extension SearchViewModel {

    // MARK: - Podcast Search

    func searchPodcasts(_ query: String) async {
        error = nil

        let api = self.api

        do {
            let parsed = SearchQueryParser.parse(query)
            let apiQueries = buildApiQueries(from: parsed)
            guard let primaryQuery = apiQueries.first else { return }

            let hasCategory = !filters.categories.isEmpty

            var options = SearchOptions()
            options.max = hasCategory ? AppConstants.searchResultsWithCategory : AppConstants.searchResultsDefault
            options.fulltext = true
            // `similar` widens the response with near matches, which is what
            // makes a misspelled query still find the podcast. Safe here
            // because nothing is truncated: everything is filtered and ranked
            // client-side, so weaker matches simply sort to the bottom.
            options.similar = true

            // Hybrid: title search + term search, deduplicated
            var allFeeds: [PodcastIndexFeed] = []
            var seenIds = Set<Int>()

            func collect(_ feeds: [PodcastIndexFeed]?) {
                for feed in feeds ?? [] where seenIds.insert(feed.id).inserted {
                    allFeeds.append(feed)
                }
            }

            // Title search runs on the primary branch only. It exists to boost
            // exact title hits, and repeating it per OR branch would double the
            // rate-limited request count for very little extra recall.
            if let titleRes = try? await api.searchByTitle(
                primaryQuery,
                options: SearchOptions(max: 50, similar: true, fulltext: true)
            ) {
                collect(titleRes.feeds)
            }

            guard !Task.isCancelled else { return }

            // One term search per OR branch, unioned. The primary branch is
            // allowed to throw so a failed search reports an error; additional
            // branches are best-effort, so a partial result still shows.
            for (index, apiQuery) in apiQueries.enumerated() {
                if index == 0 {
                    collect(try await api.searchByTerm(apiQuery, options: options).feeds)
                } else if let branchRes = try? await api.searchByTerm(apiQuery, options: options) {
                    collect(branchRes.feeds)
                }
                guard !Task.isCancelled else { return }
            }

            var results = PodcastTransform.transformFeeds(allFeeds)
            results = filterByLanguage(results)
            results = filterByCategory(results)

            // Apply query operators (exclude, exact phrase, OR)
            results = applyQueryOperators(results, parsed: parsed)

            // Composite ranking
            results = rankResults(results, query: primaryQuery, parsed: parsed)

            // Merge NRK results (local, instant). Catalog failure is not
            // fatal — Podcast Index results still show, with a notice.
            do {
                var nrkMatches: [Podcast] = []
                var seenNrkIds = Set<String>()
                for apiQuery in apiQueries {
                    for match in try await nrkService.searchCatalog(query: apiQuery)
                    where seenNrkIds.insert(match.id).inserted {
                        nrkMatches.append(match)
                    }
                }
                if !nrkMatches.isEmpty {
                    let piTitles = Set(results.map { $0.title.lowercased() })
                    var unique = nrkMatches.filter { !piTitles.contains($0.title.lowercased()) }
                    // NRK matches must clear the same narrowing as Podcast
                    // Index results, or a filtered search appends unfiltered
                    // NRK shows to the list.
                    unique = filterByLanguage(unique)
                    unique = filterByCategory(unique)
                    unique = applyQueryOperators(unique, parsed: parsed)
                    results.append(contentsOf: unique)
                }
            } catch {
                nrkUnavailable = true
            }

            // Apply local filters (date, sort override) after the merge so
            // they see NRK entries too.
            results = applyLocalFilters(results)

            podcasts = results

        } catch {
            if !Task.isCancelled {
                self.error = "Søket feilet. Prøv igjen."
            }
        }
    }

    // MARK: - API Query Builder

    /// Builds one API query per OR alternative.
    ///
    /// Podcast Index has no OR syntax and treats spaces as AND, so joining
    /// alternatives into a single query turns `a OR b` into `a AND b` — the
    /// opposite of what the user asked for. Instead each alternative becomes
    /// its own query, and the caller unions the responses.
    ///
    /// `krim OR true crime` parses to shouldInclude [krim, true] plus
    /// mustInclude [crime], and yields ["crime krim", "crime true"].
    ///
    /// Excluded terms are never sent: the API treats `-term` as a literal
    /// string and returns nothing. They are enforced in `applyQueryOperators`.
    func buildApiQueries(from parsed: ParsedQuery) -> [String] {
        var base: [String] = []
        for phrase in parsed.exactPhrases {
            base.append("\"\(phrase)\"")
        }
        base.append(contentsOf: parsed.mustInclude.filter { $0.count >= 2 })

        let alternatives = parsed.shouldInclude.filter { $0.count >= 2 }

        guard !alternatives.isEmpty else {
            // No OR: a single query, or nothing worth searching for
            return base.isEmpty ? [] : [base.joined(separator: " ")]
        }

        return alternatives
            .prefix(AppConstants.maxOrBranches)
            .map { (base + [$0]).joined(separator: " ") }
    }

    // MARK: - Query Operator Enforcement

    /// Enforces the operators the API cannot express. `text` must be lowercased.
    ///
    /// Matching is word-boundary based, so `-app` no longer discards every
    /// podcast whose description happens to contain "rapport".
    func matchesQueryOperators(_ text: String, parsed: ParsedQuery) -> Bool {
        for term in parsed.mustExclude where term.count >= 2 {
            if SearchQueryParser.containsTerm(term.lowercased(), in: text) { return false }
        }
        for phrase in parsed.exactPhrases {
            if !SearchQueryParser.containsTerm(phrase.lowercased(), in: text) { return false }
        }
        if !parsed.shouldInclude.isEmpty {
            let matchesAny = parsed.shouldInclude.contains {
                SearchQueryParser.containsTerm($0.lowercased(), in: text)
            }
            if !matchesAny { return false }
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

    /// Podcast Index spells the same category two ways: `/categories/list`
    /// returns `Self-Improvement`, while the `categories` map on a feed returns
    /// `Self Improvement`. The filter values come from the former and are
    /// matched against the latter, so the separator has to be normalised or
    /// every hyphenated category matches nothing at all. Verified affected:
    /// Self-Improvement, Video-Games, How-To and Role-Playing.
    func normalizedCategory(_ category: String) -> String {
        category.lowercased().replacingOccurrences(of: "-", with: " ")
    }

    func filterByCategory(_ podcasts: [Podcast]) -> [Podcast] {
        guard !filters.categories.isEmpty else { return podcasts }
        let normalizedFilters = filters.categories.map(normalizedCategory)
        return podcasts.filter { p in
            p.categories.contains { cat in
                let normalizedCat = normalizedCategory(cat)
                return normalizedFilters.contains { normalizedCat.contains($0) || $0.contains(normalizedCat) }
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
