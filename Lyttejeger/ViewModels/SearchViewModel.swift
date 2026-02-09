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
        if !filters.excludeCategories.isEmpty { count += 1 }
        if !filters.languages.isEmpty { count += 1 }
        if filters.explicit != nil { count += 1 }
        if filters.dateFrom != nil || filters.dateTo != nil { count += 1 }
        return count
    }

    var hasActiveFilters: Bool {
        !filters.categories.isEmpty || !filters.languages.isEmpty || filters.dateFrom != nil
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

    func setExplicit(_ explicit: Bool?) {
        filters.explicit = explicit
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
        let query = filters.query.trimmingCharacters(in: .whitespaces)

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

        guard query.count >= 2 else { return }

        if activeTab == .episodes {
            await searchEpisodes(query)
        } else {
            await searchPodcasts(query)
        }
    }

    // MARK: - Podcast Search

    private func searchPodcasts(_ query: String) async {
        isLoading = true
        error = nil
        searchWarning = nil

        let api = PodcastIndexAPI.shared

        do {
            let parsed = SearchQueryParser.parse(query)
            let completeTerms = (parsed.mustInclude + parsed.shouldInclude).filter { $0.count >= 2 } + parsed.exactPhrases
            guard !completeTerms.isEmpty else {
                isLoading = false
                return
            }

            let apiQuery = completeTerms.joined(separator: " ")
            let hasCategory = !filters.categories.isEmpty

            var options = SearchOptions()
            options.max = hasCategory ? 400 : 200
            options.fulltext = true
            options.clean = filters.explicit == false
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

            // Title boost
            if FeatureFlags.titleBoost {
                results = boostTitleMatches(results, query: apiQuery)
            }

            // Freshness signal
            if FeatureFlags.freshnessSignal {
                results = applyFreshnessSignal(results)
            }

            // Apply local filters
            results = applyLocalFilters(results)

            // Merge NRK results (local, instant)
            let nrkResults = await NRKPodcastService.shared.searchCatalog(query: apiQuery)
            if !nrkResults.isEmpty {
                let piTitles = Set(results.map { $0.title.lowercased() })
                let unique = nrkResults.filter { !piTitles.contains($0.title.lowercased()) }
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
        let completeTerms = (parsed.mustInclude + parsed.shouldInclude).filter { $0.count >= 2 } + parsed.exactPhrases
        guard !completeTerms.isEmpty else {
            isLoading = false
            return
        }

        let apiQuery = completeTerms.joined(separator: " ")
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
            let limit = FeatureFlags.expandedEpisodeSearch ? 50 : 20
            let topPodcasts = Array(podcasts.prefix(limit))
            let feedIds = topPodcasts.compactMap { Int($0.id) }
            let podcastMap = Dictionary(uniqueKeysWithValues: topPodcasts.map { ($0.id, $0) })

            if let epsRes = try? await api.episodesByFeedIds(feedIds, max: 200) {
                let eps = PodcastTransform.transformEpisodes(epsRes.items ?? [])
                for (idx, ep) in eps.enumerated() {
                    guard !existingIds.contains(ep.id) else { continue }
                    let apiEp = epsRes.items?[idx]
                    let podcast = podcastMap[String(apiEp?.feedId ?? 0)]

                    let text = "\(ep.title) \(ep.description)".lowercased()
                    let matchesTerm = completeTerms.isEmpty || completeTerms.contains { text.contains($0.lowercased()) }
                    guard matchesTerm else { continue }

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

        if let explicit = filters.explicit {
            filtered = filtered.filter { $0.explicit == explicit }
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

    private func boostTitleMatches(_ podcasts: [Podcast], query: String) -> [Podcast] {
        let queryNorm = query.lowercased()
        return podcasts.sorted { a, b in
            let aTitle = a.title.lowercased()
            let bTitle = b.title.lowercased()
            let scoreA = aTitle == queryNorm ? 3 : aTitle.hasPrefix(queryNorm) ? 2 : aTitle.contains(queryNorm) ? 1 : 0
            let scoreB = bTitle == queryNorm ? 3 : bTitle.hasPrefix(queryNorm) ? 2 : bTitle.contains(queryNorm) ? 1 : 0
            return scoreA > scoreB
        }
    }

    private func applyFreshnessSignal(_ podcasts: [Podcast]) -> [Podcast] {
        let now = Date()
        let daySeconds: TimeInterval = 86400

        return podcasts.sorted { a, b in
            let aDate = Self.isoFormatter.date(from: a.lastUpdated) ?? .distantPast
            let bDate = Self.isoFormatter.date(from: b.lastUpdated) ?? .distantPast
            let aDays = now.timeIntervalSince(aDate) / daySeconds
            let bDays = now.timeIntervalSince(bDate) / daySeconds

            func score(_ days: TimeInterval) -> Int {
                if days < 30 { return 2 }
                if days < 180 { return 1 }
                if days < 365 { return 0 }
                return -1
            }

            return score(aDays) > score(bDays)
        }
    }
}
