import Foundation

// MARK: - Podcast

struct Podcast: Identifiable, Hashable, Sendable {
    let id: String
    var guid: String?
    var title: String
    var author: String
    var description: String
    var imageUrl: String
    var feedUrl: String
    var websiteUrl: String?
    var categories: [String]
    var language: String
    var episodeCount: Int
    var lastUpdated: String
    var rating: Double
    var explicit: Bool
    var itunesId: Int?

    /// True if this podcast comes from the NRK feed source.
    var isNRKFeed: Bool { id.hasPrefix("nrk:") }

    /// The NRK RSS slug (e.g. "abels_taarn"), or nil if not an NRK podcast.
    var nrkSlug: String? { isNRKFeed ? String(id.dropFirst(4)) : nil }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Episode

struct Episode: Identifiable, Hashable, Sendable {
    let id: String
    var podcastId: String
    var title: String
    var description: String
    var audioUrl: String
    var duration: TimeInterval
    var publishedAt: String
    var imageUrl: String?
    var transcriptUrl: String?
    var chaptersUrl: String?
    var season: Int?
    var episode: Int?
    var episodeType: EpisodeType?
    var soundbites: [Soundbite]?
}

enum EpisodeType: String, Sendable {
    case full
    case trailer
    case bonus
}

// MARK: - Chapter (Podcasting 2.0)

struct Chapter: Identifiable, Hashable, Sendable {
    var id: String { "\(startTime)-\(title)" }
    var startTime: TimeInterval
    var title: String
    var img: String?
    var url: String?
    var toc: Bool?
    var endTime: TimeInterval?
}

// MARK: - Soundbite (Podcasting 2.0)

struct Soundbite: Hashable, Sendable {
    var startTime: TimeInterval
    var duration: TimeInterval
    var title: String
}

// MARK: - Episode with Podcast metadata (for search results)

struct EpisodeWithPodcast: Identifiable, Sendable {
    var id: String { episode.id }
    var episode: Episode
    var podcast: Podcast?
    var podcastTitle: String
    var podcastAuthor: String
    var podcastImage: String
    var feedLanguage: String
}
