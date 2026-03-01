import Foundation

extension SearchViewModel {

    // MARK: - Browse

    func browse() async {
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
            results = filterByLanguage(results)
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
