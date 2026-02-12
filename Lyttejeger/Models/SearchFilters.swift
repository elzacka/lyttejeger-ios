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

enum DurationFilter: String, CaseIterable, Sendable {
    case under15 = "under15"
    case from15to30 = "15to30"
    case from30to60 = "30to60"
    case over60 = "over60"

    var label: String {
        switch self {
        case .under15: "Under 15 min"
        case .from15to30: "15–30 min"
        case .from30to60: "30–60 min"
        case .over60: "Over 60 min"
        }
    }

    func matches(duration: TimeInterval) -> Bool {
        switch self {
        case .under15: duration > 0 && duration < 900
        case .from15to30: duration >= 900 && duration < 1800
        case .from30to60: duration >= 1800 && duration < 3600
        case .over60: duration >= 3600
        }
    }
}

struct SearchFilters: Equatable, Sendable {
    var query: String = ""
    var categories: [String] = []
    var languages: [String] = []
    var durationFilter: DurationFilter?
    var sortBy: SortOption = .relevance
    var dateFrom: DateFilter?
    var dateTo: DateFilter?
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
}
