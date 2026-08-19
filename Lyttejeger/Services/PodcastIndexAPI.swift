import Foundation
import CryptoKit

// MARK: - API Response Types

struct PodcastIndexFeed: Decodable, Sendable {
    let id: Int
    let podcastGuid: String?
    let title: String?
    let url: String?
    let originalUrl: String?
    let link: String?
    let description: String?
    let author: String?
    let ownerName: String?
    let image: String?
    let artwork: String?
    let lastUpdateTime: Int?
    let lastCrawlTime: Int?
    let lastParseTime: Int?
    let itunesId: Int?
    let language: String?
    let explicit: Bool?
    let episodeCount: Int?
    let crawlErrors: Int?
    let parseErrors: Int?
    let categories: [String: String]?
    let dead: Int?
}

struct PodcastIndexSoundbite: Decodable, Sendable {
    let startTime: Double
    let duration: Double
    let title: String?
}

struct PodcastIndexEpisode: Decodable, Sendable {
    let id: Int
    let title: String?
    let link: String?
    let description: String?
    let guid: String?
    let datePublished: Int?
    let datePublishedPretty: String?
    let enclosureUrl: String?
    let enclosureType: String?
    let enclosureLength: Int?
    let duration: Int?
    let explicit: Int?
    let episode: Int?
    let episodeType: String?
    let season: Int?
    let image: String?
    let feedItunesId: Int?
    let feedImage: String?
    let feedId: Int?
    let feedLanguage: String?
    let feedDead: Int?
    let chaptersUrl: String?
    let transcriptUrl: String?
    let soundbite: PodcastIndexSoundbite?
    let soundbites: [PodcastIndexSoundbite]?
    let feedTitle: String?
    let feedAuthor: String?
}

struct SearchResponse: Decodable, Sendable {
    let status: String?
    let feeds: [PodcastIndexFeed]?
    let count: Int?
    let query: String?
    let description: String?
}

struct EpisodesResponse: Decodable, Sendable {
    let status: String?
    let items: [PodcastIndexEpisode]?
    let count: Int?
    let description: String?
}

struct PodcastByIdResponse: Decodable, Sendable {
    let status: String?
    let feed: PodcastIndexFeed?
    let description: String?
}

// MARK: - Search Options

/// Options for `/search/byterm` and `/search/bytitle`.
///
/// Deliberately has no `lang`/`cat`/`notcat`: neither search endpoint accepts
/// them. Only `/podcasts/trending` does. Sending them was silently ignored by
/// the server, so language and category narrowing happens client-side and the
/// result caps are sized to leave enough candidates for that.
struct SearchOptions: Sendable {
    var max: Int = 30
    var clean: Bool = false
    var similar: Bool = false
    var fulltext: Bool = true
}

// MARK: - API Errors

enum PodcastIndexError: Error, LocalizedError {
    case authenticationFailed
    case rateLimitExceeded
    case notFound
    case serverError(Int)
    case networkError(Error)
    case invalidResponse
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .authenticationFailed: "API-autentisering feilet"
        case .rateLimitExceeded: "For mange forespørsler"
        case .notFound: "Ikke funnet"
        case .serverError(let code): "Serverfeil: \(code)"
        case .networkError: "Nettverksfeil"
        case .invalidResponse: "Ugyldig svar"
        case .notConfigured: "API ikke konfigurert"
        }
    }
}

// MARK: - API Client

actor PodcastIndexAPI: PodcastSearching {
    static let shared = PodcastIndexAPI()

    private let session: URLSession
    private let rateLimiter = RateLimiter(minInterval: AppConstants.podcastIndexRateLimit)
    private var cache = TTLCache<Data>(ttl: AppConstants.apiCacheTTL, maxSize: AppConstants.apiCacheMaxSize)
    private let maxRetries = AppConstants.apiMaxRetries
    private let decoder: JSONDecoder

    /// Internal so tests can inject a URLProtocol-backed configuration.
    /// Production always goes through `.shared`, which takes the default.
    init(configuration: URLSessionConfiguration = .default) {
        let config = configuration
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        // No certificate pinning. api.podcastindex.org uses Let's Encrypt, which
        // rotates the leaf every 90 days and rotated its whole CA hierarchy in
        // 2026. Pinning failed closed and silently broke search in v1.0.7 for
        // every user until an app update shipped. Let's Encrypt advises against
        // pinning their certificates for exactly this reason. ATS still enforces
        // TLS 1.2+, a valid chain to a system trust anchor, and hostname
        // validation; the endpoint carries public podcast metadata only.
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
    }

    func clearCache() {
        cache.removeAll()
    }

    var isConfigured: Bool {
        let key = Secrets.podcastIndexAPIKey
        return !key.isEmpty && key != "YOUR_API_KEY_HERE"
    }

    // MARK: - Auth Headers

    private func authHeaders() -> [String: String] {
        let apiKey = Secrets.podcastIndexAPIKey
        let apiSecret = Secrets.podcastIndexAPISecret
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let hashInput = apiKey + apiSecret + timestamp
        let hash = Insecure.SHA1.hash(data: Data(hashInput.utf8))
            .map { String(format: "%02x", $0) }
            .joined()

        return [
            "X-Auth-Date": timestamp,
            "X-Auth-Key": apiKey,
            "Authorization": hash,
            "User-Agent": "\(AppConstants.appName)/\(AppConstants.appVersion)",
        ]
    }

    // MARK: - Core Request

    private func apiRequest<T: Decodable>(
        endpoint: String,
        params: [String: String] = [:],
        retryCount: Int = 0,
        retryServerErrors: Bool = true
    ) async throws -> T {
        guard var components = URLComponents(string: AppConstants.apiBase + endpoint) else {
            throw PodcastIndexError.invalidResponse
        }
        // URLQueryItem handles percent-encoding of parameter values
        if !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let url = components.url else {
            throw PodcastIndexError.invalidResponse
        }

        let cacheKey = url.absoluteString

        // Check cache
        if let cached = cache.value(for: cacheKey) {
            return try decoder.decode(T.self, from: cached)
        }

        // Rate limit
        await rateLimiter.acquire()

        var request = URLRequest(url: url)
        for (key, value) in authHeaders() {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PodcastIndexError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200...299:
                // Cache successful response
                cache.insert(data, for: cacheKey)
                return try decoder.decode(T.self, from: data)

            case 401, 403:
                throw PodcastIndexError.authenticationFailed

            case 404:
                throw PodcastIndexError.notFound

            case 429:
                if retryCount < maxRetries {
                    let retryAfter = min(
                        Double(httpResponse.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 2.0,
                        AppConstants.apiRetryAfterMaxSeconds
                    )
                    try await Task.sleep(for: .seconds(retryAfter))
                    return try await apiRequest(
                        endpoint: endpoint,
                        params: params,
                        retryCount: retryCount + 1,
                        retryServerErrors: retryServerErrors
                    )
                }
                throw PodcastIndexError.rateLimitExceeded

            case 500...599:
                if retryServerErrors && retryCount < maxRetries {
                    // Exponential backoff: 1s, 2s, 4s for retries 0, 1, 2
                    let delay = AppConstants.apiRetryBaseDelay * pow(2.0, Double(retryCount))
                    try await Task.sleep(for: .seconds(delay))
                    return try await apiRequest(
                        endpoint: endpoint,
                        params: params,
                        retryCount: retryCount + 1,
                        retryServerErrors: retryServerErrors
                    )
                }
                throw PodcastIndexError.serverError(httpResponse.statusCode)

            default:
                throw PodcastIndexError.serverError(httpResponse.statusCode)
            }
        } catch let error as PodcastIndexError {
            throw error
        } catch {
            throw PodcastIndexError.networkError(error)
        }
    }

    // MARK: - Search Endpoints

    func searchByTitle(_ query: String, options: SearchOptions = SearchOptions()) async throws -> SearchResponse {
        var params: [String: String] = [
            "q": query,
            "max": String(options.max),
        ]
        if options.fulltext { params["fulltext"] = "" }
        if options.similar { params["similar"] = "" }
        return try await apiRequest(endpoint: "/search/bytitle", params: params)
    }

    func searchByTerm(_ query: String, options: SearchOptions = SearchOptions()) async throws -> SearchResponse {
        var params: [String: String] = [
            "q": query,
            "max": String(options.max),
        ]
        if options.fulltext { params["fulltext"] = "" }
        if options.similar { params["similar"] = "" }
        if options.clean { params["clean"] = "" }
        return try await apiRequest(endpoint: "/search/byterm", params: params)
    }

    func searchByPerson(_ name: String, max: Int = 50) async throws -> EpisodesResponse {
        let params: [String: String] = [
            "q": name,
            "max": String(max),
            "fulltext": "",
        ]
        return try await apiRequest(endpoint: "/search/byperson", params: params)
    }

    // MARK: - Episode Endpoints

    func episodesByFeedId(_ feedId: Int, max: Int = 20, since: Int? = nil) async throws -> EpisodesResponse {
        var params: [String: String] = [
            "id": String(feedId),
            "max": String(max),
            "fulltext": "",
        ]
        if let since { params["since"] = String(since) }
        return try await apiRequest(endpoint: "/episodes/byfeedid", params: params)
    }

    func episodesByFeedIds(_ feedIds: [Int], max: Int = 100, since: Int? = nil) async throws -> EpisodesResponse {
        guard !feedIds.isEmpty else {
            return EpisodesResponse(status: "true", items: [], count: 0, description: "")
        }
        let limitedIds = feedIds.prefix(200)
        var params: [String: String] = [
            "id": limitedIds.map(String.init).joined(separator: ","),
            "max": String(max),
            "fulltext": "",
        ]
        if let since { params["since"] = String(since) }
        return try await apiRequest(endpoint: "/episodes/byfeedid", params: params)
    }

    // MARK: - Podcast Lookup

    func podcastByFeedId(_ feedId: Int) async throws -> PodcastByIdResponse {
        try await apiRequest(endpoint: "/podcasts/byfeedid", params: ["id": String(feedId)])
    }

    func podcastByGuid(_ guid: String) async throws -> PodcastByIdResponse {
        try await apiRequest(endpoint: "/podcasts/byguid", params: ["guid": guid])
    }

    /// Resolves a feed URL to a full podcast record.
    /// Used by OPML import, where the file gives a feed URL and a title but
    /// none of the metadata the app needs.
    func podcastByFeedUrl(_ feedUrl: String) async throws -> PodcastByIdResponse {
        try await apiRequest(endpoint: "/podcasts/byfeedurl", params: ["url": feedUrl])
    }

    // MARK: - Browse/Trending

    /// Trending feeds, optionally narrowed by language and category.
    ///
    /// A `cat` value the endpoint dislikes makes it answer 500 rather than an
    /// empty list, and it does so every time — verified for Self-Improvement,
    /// Tabletop, Role-Playing, Video-Games, Climate, How-To, Cryptocurrency
    /// and Weather. Retrying a deterministic 500 only delays the caller's
    /// fallback by seven seconds, so retries are off whenever `cat` is set.
    func trending(max: Int = 50, lang: String? = nil, cat: String? = nil, notcat: String? = nil) async throws -> SearchResponse {
        var params: [String: String] = ["max": String(max)]
        if let lang { params["lang"] = lang }
        if let cat { params["cat"] = cat }
        if let notcat { params["notcat"] = notcat }
        return try await apiRequest(
            endpoint: "/podcasts/trending",
            params: params,
            retryServerErrors: cat == nil
        )
    }

    func recentEpisodes(max: Int = 50, lang: String? = nil) async throws -> EpisodesResponse {
        var params: [String: String] = [
            "max": String(max),
            "fulltext": "",
        ]
        if let lang { params["lang"] = lang }
        return try await apiRequest(endpoint: "/recent/episodes", params: params)
    }
}
