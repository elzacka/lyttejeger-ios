import Foundation
import SwiftData

@Observable
@MainActor
final class SearchViewModel {
    private static let isoFormatter = ISO8601DateFormatter()

    var filters = SearchFilters()
    var podcasts: [Podcast] = []
    var episodes: [EpisodeWithPodcast] = []
    var isLoading = false
    var error: String?
    var searchWarning: String?
    var activeTab: SearchTab = .podcasts

    private var searchTask: Task<Void, Never>?
    private var lastSearchResults: [Podcast] = []

    enum SearchTab: String, CaseIterable {
        case podcasts
        case episodes
    }

    var activeFilterCount: Int {
        var count = 0
        if !filters.categories.isEmpty { count += 1 }
        if !filters.languages.isEmpty { count += 1 }
        if filters.dateFrom != nil || filters.dateTo != nil { count += 1 }
        if filters.sortBy != .relevance { count += 1 }
        if filters.durationFilter != nil { count += 1 }
        return count
    }

    var hasActiveFilters: Bool {
        !filters.categories.isEmpty
        || !filters.languages.isEmpty
        || filters.dateFrom != nil
        || filters.dateTo != nil
        || filters.sortBy != .relevance
        || filters.durationFilter != nil
    }

    // MARK: - Search

    func setQuery(_ query: String) {
        filters.query = query
        debounceSearch()
    }

    func toggleCategory(_ category: String) {
        if let idx = filters.categories.firstIndex(of: category) {
            filters.categories.remove(at: idx)
        } else {
            filters.categories.append(category)
        }
        debounceSearch()
    }

    func toggleLanguage(_ language: String) {
        if let idx = filters.languages.firstIndex(of: language) {
            filters.languages.remove(at: idx)
        } else {
            filters.languages.append(language)
        }
        debounceSearch()
    }

    func setDateFrom(_ date: DateFilter?) {
        filters.dateFrom = date
        debounceSearch()
    }

    func setDateTo(_ date: DateFilter?) {
        filters.dateTo = date
        debounceSearch()
    }

    func setSortBy(_ sortBy: SortOption) {
        filters.sortBy = sortBy
        debounceSearch()
    }

    func setDurationFilter(_ duration: DurationFilter?) {
        filters.durationFilter = duration
        debounceSearch()
    }

    func toggleDurationFilter(_ duration: DurationFilter) {
        filters.durationFilter = filters.durationFilter == duration ? nil : duration
        debounceSearch()
    }

    func clearFilters() {
        filters = SearchFilters()
        podcasts = []
        episodes = []
        lastSearchResults = []
    }

    func setActiveTab(_ tab: SearchTab) {
        activeTab = tab
        debounceSearch()
    }

    private func debounceSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await performSearch()
        }
    }

    private func performSearch() async {
        let query = String(filters.query.trimmingCharacters(in: .whitespaces).prefix(AppConstants.maxSearchQueryLength))

        // Empty query with active filters -> browse
        if query.isEmpty {
            if hasActiveFilters {
                await browse()
            } else {
                podcasts = []
                episodes = []
                lastSearchResults = []
            }
            return
        }

        guard query.count >= AppConstants.minSearchQueryLength else { return }

        if activeTab == .episodes {
            await searchEpisodes(query)
        } else {
            await searchPodcasts(query)
        }
    }

    // MARK: - API Query Builder

    /// Builds the query string for the Podcast Index API from parsed operators.
    /// Re-wraps exact phrases in quotes, includes exclude terms with `-` prefix.
    /// Returns nil if no positive search terms exist.
    private func buildApiQuery(from parsed: ParsedQuery) -> String? {
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

    /// Apply parsed query operators as client-side post-filters on podcast results.
    private func applyQueryOperators(_ results: [Podcast], parsed: ParsedQuery) -> [Podcast] {
        guard !parsed.mustExclude.isEmpty
            || !parsed.exactPhrases.isEmpty
            || !parsed.shouldInclude.isEmpty else {
            return results
        }

        return results.filter { podcast in
            let text = "\(podcast.title) \(podcast.description) \(podcast.author)".lowercased()

            // Exclude: remove results containing ANY mustExclude term
            for term in parsed.mustExclude where term.count >= 2 {
                if text.contains(term.lowercased()) { return false }
            }

            // Exact phrases: require ALL present
            for phrase in parsed.exactPhrases {
                if !text.contains(phrase.lowercased()) { return false }
            }

            // OR: require at least ONE shouldInclude term present
            if !parsed.shouldInclude.isEmpty {
                let hasMatch = parsed.shouldInclude.contains { text.contains($0.lowercased()) }
                if !hasMatch { return false }
            }

            return true
        }
    }

    /// Apply parsed query operators as client-side post-filters on episode results.
    private func applyQueryOperators(_ results: [EpisodeWithPodcast], parsed: ParsedQuery) -> [EpisodeWithPodcast] {
        guard !parsed.mustExclude.isEmpty
            || !parsed.exactPhrases.isEmpty
            || !parsed.shouldInclude.isEmpty else {
            return results
        }

        return results.filter { item in
            let text = "\(item.episode.title) \(item.episode.description) \(item.podcastTitle)".lowercased()

            for term in parsed.mustExclude where term.count >= 2 {
                if text.contains(term.lowercased()) { return false }
            }

            for phrase in parsed.exactPhrases {
                if !text.contains(phrase.lowercased()) { return false }
            }

            if !parsed.shouldInclude.isEmpty {
                let hasMatch = parsed.shouldInclude.contains { text.contains($0.lowercased()) }
                if !hasMatch { return false }
            }

            return true
        }
    }

    // MARK: - Composite Ranking

    /// Compute a composite relevance score for each podcast and sort descending.
    /// Replaces the old sequential boostTitleMatches + applyFreshnessSignal.
    private func rankResults(_ podcasts: [Podcast], query: String, parsed: ParsedQuery) -> [Podcast] {
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
            let lastUpdated = Self.isoFormatter.date(from: podcast.lastUpdated) ?? .distantPast
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

    // MARK: - Podcast Search

    private func searchPodcasts(_ query: String) async {
        isLoading = true
        error = nil
        searchWarning = nil

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
            options.lang = hasCategory ? nil : (getApiLanguageCodes(filters.languages) ?? AppConstants.allowedLanguagesAPI)
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

            // Language filter
            if !filters.languages.isEmpty {
                results = results.filter { p in
                    filters.languages.contains { matchesLanguageFilter(p.language, filterLabel: $0) }
                }
            } else {
                results = results.filter { isAllowedLanguage($0.language) }
            }

            // Category filter
            if hasCategory {
                results = results.filter { p in
                    p.categories.contains { cat in
                        filters.categories.contains { filter in
                            cat.lowercased().contains(filter.lowercased()) ||
                            filter.lowercased().contains(cat.lowercased())
                        }
                    }
                }
            }

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

            lastSearchResults = results
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

    // MARK: - Episode Search

    private func searchEpisodes(_ query: String) async {
        isLoading = true
        error = nil
        searchWarning = nil

        let api = PodcastIndexAPI.shared

        let parsed = SearchQueryParser.parse(query)
        guard let apiQuery = buildApiQuery(from: parsed) else {
            isLoading = false
            return
        }

        let completeTerms = (parsed.mustInclude + parsed.shouldInclude).filter { $0.count >= 2 } + parsed.exactPhrases
        var allEpisodes: [EpisodeWithPodcast] = []
        var existingIds = Set<String>()

        // Strategy 1: byperson search
        if let personRes = try? await api.searchByPerson(apiQuery, max: 50) {
            let eps = PodcastTransform.transformEpisodes(personRes.items ?? [])
            for (idx, ep) in eps.enumerated() {
                guard !existingIds.contains(ep.id) else { continue }
                let apiEp = personRes.items?[idx]

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
        }

        guard !Task.isCancelled else { return }

        // Strategy 2: episodes from matching podcasts
        if !podcasts.isEmpty {
            let topPodcasts = Array(podcasts.prefix(AppConstants.episodeSearchPodcastLimit))
            let feedIds = topPodcasts.compactMap { Int($0.id) }
            let podcastMap = Dictionary(uniqueKeysWithValues: topPodcasts.map { ($0.id, $0) })

            if let epsRes = try? await api.episodesByFeedIds(feedIds, max: 200) {
                let eps = PodcastTransform.transformEpisodes(epsRes.items ?? [])
                for (idx, ep) in eps.enumerated() {
                    guard !existingIds.contains(ep.id) else { continue }
                    let apiEp = epsRes.items?[idx]
                    let podcast = podcastMap[String(apiEp?.feedId ?? 0)]

                    let text = "\(ep.title) \(ep.description)".lowercased()
                    // AND: all mustInclude terms must be present
                    let hasAllRequired = parsed.mustInclude.filter { $0.count >= 2 }.allSatisfy { text.contains($0.lowercased()) }
                    // OR: at least one shouldInclude term (if any)
                    let hasAnyShouldInclude = parsed.shouldInclude.isEmpty || parsed.shouldInclude.contains { text.contains($0.lowercased()) }
                    // Exact phrases
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
                (Self.isoFormatter.date(from: $0.episode.publishedAt) ?? .distantPast) >= fromDate
            }
        }
        if let dateTo = filters.dateTo {
            let toDate = dateTo.date
            allEpisodes = allEpisodes.filter {
                (Self.isoFormatter.date(from: $0.episode.publishedAt) ?? .distantFuture) <= toDate
            }
        }

        // Sort
        switch filters.sortBy {
        case .newest:
            allEpisodes.sort { a, b in
                let dateA = Self.isoFormatter.date(from: a.episode.publishedAt) ?? .distantPast
                let dateB = Self.isoFormatter.date(from: b.episode.publishedAt) ?? .distantPast
                return dateA > dateB
            }
        case .oldest:
            allEpisodes.sort { a, b in
                let dateA = Self.isoFormatter.date(from: a.episode.publishedAt) ?? .distantPast
                let dateB = Self.isoFormatter.date(from: b.episode.publishedAt) ?? .distantPast
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

        if !Task.isCancelled {
            isLoading = false
        }
    }

    // MARK: - Browse

    private func browse() async {
        isLoading = true
        error = nil

        let api = PodcastIndexAPI.shared

        do {
            let res = try await api.trending(
                max: !filters.categories.isEmpty ? 200 : 100,
                lang: getApiLanguageCodes(filters.languages),
                cat: filters.categories.isEmpty ? nil : filters.categories.joined(separator: ",")
            )

            var results = PodcastTransform.transformFeeds(res.feeds ?? [])

            if !filters.languages.isEmpty {
                results = results.filter { p in
                    filters.languages.contains { matchesLanguageFilter(p.language, filterLabel: $0) }
                }
            } else {
                results = results.filter { isAllowedLanguage($0.language) }
            }

            results = applyLocalFilters(results)
            podcasts = results
            episodes = []

        } catch {
            if !Task.isCancelled {
                self.error = "Kunne ikke hente innhold. Prøv igjen."
            }
        }

        if !Task.isCancelled {
            isLoading = false
        }
    }

    // MARK: - Local Filters

    private func applyLocalFilters(_ podcasts: [Podcast]) -> [Podcast] {
        var filtered = podcasts

        if let dateFrom = filters.dateFrom {
            let fromDate = dateFrom.date
            filtered = filtered.filter {
                (Self.isoFormatter.date(from: $0.lastUpdated) ?? .distantPast) >= fromDate
            }
        }

        if let dateTo = filters.dateTo {
            let toDate = dateTo.date
            filtered = filtered.filter {
                (Self.isoFormatter.date(from: $0.lastUpdated) ?? .distantFuture) <= toDate
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

    private func isAllowedLanguage(_ lang: String) -> Bool {
        allLanguages.contains { matchesLanguageFilter(lang, filterLabel: $0) }
    }
}
