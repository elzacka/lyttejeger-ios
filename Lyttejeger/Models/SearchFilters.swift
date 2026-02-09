import Foundation

struct DateFilter: Equatable, Sendable {
    var day: Int
    var month: Int  // 1-12
    var year: Int

    var date: Date {
        var components = DateComponents()
        components.day = day
        components.month = month
        components.year = year
        return Calendar.current.date(from: components) ?? Date()
    }
}

struct SearchFilters: Equatable, Sendable {
    var query: String = ""
    var categories: [String] = []
    var excludeCategories: [String] = []
    var languages: [String] = []
    var maxDuration: TimeInterval? = nil
    var sortBy: SortOption = .relevance
    var explicit: Bool? = nil
    var dateFrom: DateFilter? = nil
    var dateTo: DateFilter? = nil
}

enum SortOption: String, CaseIterable, Sendable {
    case relevance = "relevance"
    case newest = "newest"
    case oldest = "oldest"
    case popular = "popular"

    var label: String {
        switch self {
        case .relevance: "Relevans"
        case .newest: "Nyeste"
        case .oldest: "Eldste"
        case .popular: "Populære"
        }
    }
}

struct FilterOption: Identifiable, Hashable, Sendable {
    var id: String { value }
    var value: String
    var label: String
    var count: Int?
}
