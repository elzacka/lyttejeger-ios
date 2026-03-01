import Foundation
import SwiftData

@Observable
@MainActor
final class SearchViewModel {
    var filters = SearchFilters()
    var podcasts: [Podcast] = []
    var episodes: [EpisodeWithPodcast] = []
    var isLoading = false
    var error: String?
    var activeTab: SearchTab = .podcasts

    private var searchTask: Task<Void, Never>?

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
        if activeTab == .episodes && filters.durationFilter != nil { count += 1 }
        return count
    }

    var hasActiveFilters: Bool { activeFilterCount > 0 }

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
    }

    func setActiveTab(_ tab: SearchTab) {
        activeTab = tab
        debounceSearch()
    }

    // MARK: - Search Coordination

    private func debounceSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .seconds(AppConstants.searchDebounce))
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
}
