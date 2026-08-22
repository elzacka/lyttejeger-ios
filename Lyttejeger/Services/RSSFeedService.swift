import Foundation

/// Fetches and parses a podcast RSS feed from an arbitrary URL.
///
/// Exists for subscriptions Podcast Index does not know about. OPML import
/// keeps those with a `feed:` id plus the feed URL from the file, and without
/// this they would sit in the following list and never load a single episode.
/// That made OPML import look like it worked while quietly producing dead
/// ends, which is worse than refusing the import outright.
///
/// Shares `PodcastRSSParser` with the NRK service; both read plain RSS 2.0.
actor RSSFeedService: RSSFeedFetching {
    static let shared = RSSFeedService()

    private static let feedTTL: TimeInterval = 30 * 60

    /// Tests pass a configuration carrying a stubbed URLProtocol. Same seam as
    /// `ChapterService`, `TranscriptService` and `PodcastIndexAPI`.
    private let session: URLSession

    init(configuration: URLSessionConfiguration? = nil) {
        let config = configuration ?? {
            let c = URLSessionConfiguration.default
            c.timeoutIntervalForRequest = 30
            c.timeoutIntervalForResource = 60
            return c
        }()
        session = URLSession(configuration: config)
    }

    private var feedCache = TTLCache<PodcastFeedResult>(ttl: RSSFeedService.feedTTL, maxSize: 30)

    /// - Parameter podcastId: the id episodes are tagged with, so queue rows
    ///   and playback positions point back at the right podcast.
    func fetchEpisodes(feedUrl: String, podcastId: String) async throws -> PodcastFeedResult {
        if let cached = feedCache.value(for: feedUrl) {
            return cached
        }

        // Same https-only rule as every other fetch in the app. The URL comes
        // from a file the user imported, so it is not trusted input.
        guard let url = URL(string: feedUrl),
              url.scheme?.lowercased() == "https" else {
            throw RSSFeedError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw RSSFeedError.fetchFailed
        }

        let result = PodcastRSSParser(data: data, podcastId: podcastId).parse()

        // Only cache a real parse, so a transient failure does not lock the
        // feed out for the whole TTL
        guard !result.episodes.isEmpty || !result.podcastTitle.isEmpty else {
            throw RSSFeedError.parseFailed
        }
        feedCache.insert(result, for: feedUrl)

        return result
    }

    func clearCache() {
        feedCache.removeAll()
    }

    enum RSSFeedError: Error, LocalizedError {
        case invalidURL
        case fetchFailed
        case parseFailed

        var errorDescription: String? {
            switch self {
            case .invalidURL: "Ugyldig feed-adresse"
            case .fetchFailed: "Kunne ikke hente feeden"
            case .parseFailed: "Kunne ikke tolke feeden"
            }
        }
    }
}
