import Foundation

// MARK: - Service Protocols
// Protocols enable dependency injection for testability.
// Production singletons (.shared) are the default implementations.

@MainActor
protocol AudioPlaying: AnyObject {
    var isPlaying: Bool { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
    var isLoading: Bool { get }
    var hasError: Bool { get }
    var playbackSpeed: Float { get }
    var currentEpisode: Episode? { get }
    var currentPodcastTitle: String? { get }
    var currentPodcastImage: String? { get }
    var onRemotePlay: (() -> Void)? { get set }
    var pausedAt: Date? { get }

    func play(episode: Episode, podcastTitle: String?, podcastImage: String?)
    func togglePlayPause()
    func pause()
    func seek(to time: TimeInterval)
    func skipBackward()
    func skipForward()
    func setSpeed(_ speed: Float)
    func setVolume(_ volume: Float)
    func stop()
}

protocol PodcastSearching: Sendable {
    func searchByTitle(_ query: String, options: SearchOptions) async throws -> SearchResponse
    func searchByTerm(_ query: String, options: SearchOptions) async throws -> SearchResponse
    func searchByPerson(_ name: String, max: Int) async throws -> EpisodesResponse
    func episodesByFeedId(_ feedId: Int, max: Int, since: Int?) async throws -> EpisodesResponse
    func episodesByFeedIds(_ feedIds: [Int], max: Int, since: Int?) async throws -> EpisodesResponse
    func podcastByFeedId(_ feedId: Int) async throws -> PodcastByIdResponse
    func trending(max: Int, lang: String?, cat: String?, notcat: String?) async throws -> SearchResponse
    var isConfigured: Bool { get async }
}

extension PodcastSearching {
    func searchByTitle(_ query: String) async throws -> SearchResponse {
        try await searchByTitle(query, options: SearchOptions())
    }
    func searchByPerson(_ name: String) async throws -> EpisodesResponse {
        try await searchByPerson(name, max: 50)
    }
    func episodesByFeedId(_ feedId: Int, max: Int = 20) async throws -> EpisodesResponse {
        try await episodesByFeedId(feedId, max: max, since: nil)
    }
    func episodesByFeedIds(_ feedIds: [Int], max: Int = 100) async throws -> EpisodesResponse {
        try await episodesByFeedIds(feedIds, max: max, since: nil)
    }
    func trending(max: Int = 50, lang: String? = nil, cat: String? = nil) async throws -> SearchResponse {
        try await trending(max: max, lang: lang, cat: cat, notcat: nil)
    }
}

protocol NRKSearching: Sendable {
    func searchCatalog(query: String) async -> [Podcast]
    func fetchEpisodes(nrkSlug: String) async throws -> NRKFeedResult
}

protocol ChapterFetching: Sendable {
    func fetchChapters(from url: String) async -> [Chapter]
}

protocol TranscriptFetching: Sendable {
    func fetchTranscript(from url: String) async -> Transcript?
}
