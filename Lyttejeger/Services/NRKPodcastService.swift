import Foundation
import os

// MARK: - NRK Catalog Entry (matches podcasts.json)

struct NRKCatalogEntry: Decodable, Sendable {
    let id: String
    let title: String
    let season: String?
    let enabled: Bool
    let ignore: Bool?
    let hidden: Bool?
}


// MARK: - Service

actor NRKPodcastService: NRKSearching {
    static let shared = NRKPodcastService()
    private let decoder = JSONDecoder()

    // NRK data comes from the community project sindrel/nrk-pod-feeds — a
    // third-party dependency with no SLA. Failures must degrade gracefully.
    private static let catalogURL = "https://raw.githubusercontent.com/sindrel/nrk-pod-feeds/master/podcasts.json"
    private static let feedBaseURL = AppConstants.nrkFeedBaseURL

    private static let catalogTTL: TimeInterval = 24 * 60 * 60   // 24 hours
    private static let feedTTL: TimeInterval = 30 * 60            // 30 minutes

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    private var catalog: [NRKCatalogEntry] = []
    private var catalogFetchedAt: Date?

    private var feedCache = TTLCache<PodcastFeedResult>(ttl: NRKPodcastService.feedTTL, maxSize: 30)

    // MARK: - Catalog

    /// Ensures the catalog is loaded and returns active entries.
    func ensureCatalog() async throws -> [NRKCatalogEntry] {
        if let fetched = catalogFetchedAt,
           Date().timeIntervalSince(fetched) < Self.catalogTTL,
           !catalog.isEmpty {
            return catalog
        }

        guard let url = URL(string: Self.catalogURL) else {
            throw NRKError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NRKError.fetchFailed
        }

        let entries = try decoder.decode([NRKCatalogEntry].self, from: data)
        catalog = entries.filter { $0.enabled && $0.ignore != true && $0.hidden != true }
        catalogFetchedAt = Date()
        return catalog
    }

    /// Splits a query into the words used for catalog title matching.
    ///
    /// Matching each word on its own, rather than the whole query as a single
    /// substring, is what lets word order stop deciding the outcome: with the
    /// old behaviour "abels tårn" found the podcast but "tårn abels" did not,
    /// and any query carrying an extra required term matched nothing at all.
    /// Quotes are separators too, since exact phrases reach here still quoted.
    nonisolated static func searchTokens(from query: String) -> [String] {
        query
            .lowercased()
            .split { $0 == " " || $0 == "\"" }
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    /// Searches the cached catalog locally by title. Zero network after first load.
    /// Throws if the catalog cannot be fetched, so callers can tell the user
    /// that NRK results are unavailable instead of silently omitting them.
    func searchCatalog(query: String) async throws -> [Podcast] {
        guard !query.isEmpty else { return [] }

        let entries = try await ensureCatalog()

        let tokens = Self.searchTokens(from: query)
        guard !tokens.isEmpty else { return [] }

        return entries
            .filter { entry in
                let title = cleanTitle(entry.title).lowercased()
                return tokens.allSatisfy { title.contains($0) }
            }
            .map { toPodcast($0) }
    }

    // MARK: - RSS Feed

    /// Fetches and parses an NRK podcast's RSS feed, returning metadata + episodes.
    func fetchEpisodes(nrkSlug: String) async throws -> PodcastFeedResult {
        // Check cache
        if let cached = feedCache.value(for: nrkSlug) {
            return cached
        }

        // Validate slug contains only safe characters (defense against path traversal)
        guard nrkSlug.range(of: AppConstants.nrkSlugPattern, options: .regularExpression) != nil else {
            throw NRKError.invalidURL
        }

        guard let url = URL(string: "\(Self.feedBaseURL)\(nrkSlug).xml") else {
            throw NRKError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NRKError.fetchFailed
        }

        let parser = PodcastRSSParser(data: data, podcastId: "nrk:\(nrkSlug)")
        let result = parser.parse()

        // Only cache successful parses — avoid locking out retries for 30 min on parse failure
        guard !result.episodes.isEmpty || !result.podcastTitle.isEmpty else {
            throw NRKError.parseFailed
        }
        feedCache.insert(result, for: nrkSlug)

        return result
    }

    // MARK: - Mapping

    private func cleanTitle(_ title: String) -> String {
        var t = title
        // Strip "De N siste fra " prefix (N varies: 2, 5, 10, etc.)
        if let range = t.range(of: #"^De \d+ siste fra "#, options: .regularExpression) {
            t = String(t[range.upperBound...])
        }
        return t.trimmingCharacters(in: .whitespaces)
    }

    private func toPodcast(_ entry: NRKCatalogEntry) -> Podcast {
        Podcast(
            id: "nrk:\(entry.id)",
            title: cleanTitle(entry.title),
            author: "NRK",
            description: "",
            imageUrl: "",
            feedUrl: "\(Self.feedBaseURL)\(entry.id).xml",
            categories: [],
            language: "Norsk",
            episodeCount: 0,
            lastUpdated: "",
            explicit: false
        )
    }

    func clearCache() {
        catalog = []
        catalogFetchedAt = nil
        feedCache.removeAll()
    }

    // MARK: - Errors

    enum NRKError: Error, LocalizedError {
        case invalidURL
        case fetchFailed
        case parseFailed

        var errorDescription: String? {
            switch self {
            case .invalidURL: "Ugyldig NRK-URL"
            case .fetchFailed: "Kunne ikke hente NRK-data"
            case .parseFailed: "Kunne ikke tolke NRK-feed"
            }
        }
    }
}
