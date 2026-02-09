import Foundation
import CryptoKit
import Security

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

struct SearchOptions: Sendable {
    var max: Int = 30
    var clean: Bool = false
    var similar: Bool = false
    var fulltext: Bool = true
    var lang: String? = nil
    var cat: String? = nil
    var notcat: String? = nil
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

// MARK: - Cache Entry

private struct CacheEntry: Sendable {
    let data: Data
    let timestamp: Date
}

// MARK: - Certificate Pinning

private final class APIPinningDelegate: NSObject, URLSessionDelegate, Sendable {
    // SHA256 hashes of the SubjectPublicKeyInfo (SPKI) for api.podcastindex.org
    // Leaf = EC P-256, Intermediate = EC P-384
    private let pinnedKeyHashes: Set<String> = [
        "QmmepH+qOl2EfJmjYMZWo/rqHf34e9zY0qIeWy+KL8E=",
        "y7xVm0TVJNahMr2sZydE2jQH8SquXV9yLF9seROHHHU=",
    ]

    // ASN.1 headers to reconstruct SubjectPublicKeyInfo from raw EC key data
    // SecKeyCopyExternalRepresentation returns raw key; openssl hashes full SPKI
    private static let ecP256SPKIHeader: [UInt8] = [
        0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02,
        0x01, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03,
        0x42, 0x00
    ]

    private static let ecP384SPKIHeader: [UInt8] = [
        0x30, 0x76, 0x30, 0x10, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02,
        0x01, 0x06, 0x05, 0x2b, 0x81, 0x04, 0x00, 0x22, 0x03, 0x62, 0x00
    ]

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              challenge.protectionSpace.host == "api.podcastindex.org",
              let serverTrust = challenge.protectionSpace.serverTrust else {
            return (.performDefaultHandling, nil)
        }

        let policy = SecPolicyCreateSSL(true, "api.podcastindex.org" as CFString)
        SecTrustSetPolicies(serverTrust, policy)

        var error: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &error) else {
            return (.cancelAuthenticationChallenge, nil)
        }

        guard let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
            return (.cancelAuthenticationChallenge, nil)
        }
        for certificate in chain {
            guard let publicKey = SecCertificateCopyKey(certificate),
                  let rawKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as? Data else {
                continue
            }

            // Reconstruct SPKI by prepending the ASN.1 header for the key type
            let spkiHeader: [UInt8] = switch rawKeyData.count {
            case 65: Self.ecP256SPKIHeader   // EC P-256: 1 + 32 + 32
            case 97: Self.ecP384SPKIHeader   // EC P-384: 1 + 48 + 48
            default: []                       // Unknown key type — skip header
            }

            var spkiData = Data(spkiHeader)
            spkiData.append(rawKeyData)

            let hash = SHA256.hash(data: spkiData)
            let hashBase64 = Data(hash).base64EncodedString()

            if pinnedKeyHashes.contains(hashBase64) {
                return (.useCredential, URLCredential(trust: serverTrust))
            }
        }

        return (.cancelAuthenticationChallenge, nil)
    }
}

// MARK: - API Client

actor PodcastIndexAPI {
    static let shared = PodcastIndexAPI()

    private let session: URLSession
    private let rateLimiter = RateLimiter(requestsPerSecond: 1.0)
    private var cache: [String: CacheEntry] = [:]
    private let cacheTTL: TimeInterval = AppConstants.apiCacheTTL
    private let maxRetries = AppConstants.apiMaxRetries
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config, delegate: APIPinningDelegate(), delegateQueue: nil)
        self.decoder = JSONDecoder()
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
        retryCount: Int = 0
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
        if let cached = cache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return try decoder.decode(T.self, from: cached.data)
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
                cache[cacheKey] = CacheEntry(data: data, timestamp: Date())

                // Trim cache if too large
                if cache.count > AppConstants.apiCacheMaxSize {
                    let sorted = cache.sorted { $0.value.timestamp < $1.value.timestamp }
                    for entry in sorted.prefix(cache.count - AppConstants.apiCacheMaxSize) {
                        cache.removeValue(forKey: entry.key)
                    }
                }

                return try decoder.decode(T.self, from: data)

            case 401, 403:
                throw PodcastIndexError.authenticationFailed

            case 404:
                throw PodcastIndexError.notFound

            case 429:
                if retryCount < maxRetries {
                    try await Task.sleep(for: .seconds(2))
                    return try await apiRequest(endpoint: endpoint, params: params, retryCount: retryCount + 1)
                }
                throw PodcastIndexError.rateLimitExceeded

            case 500...:
                if retryCount < maxRetries {
                    let delay = AppConstants.apiRetryBaseDelay * Double(retryCount + 1)
                    try await Task.sleep(for: .seconds(delay))
                    return try await apiRequest(endpoint: endpoint, params: params, retryCount: retryCount + 1)
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
            "similar": "",
            "fulltext": "",
        ]
        if let lang = options.lang { params["lang"] = lang }
        return try await apiRequest(endpoint: "/search/bytitle", params: params)
    }

    func searchByTerm(_ query: String, options: SearchOptions = SearchOptions()) async throws -> SearchResponse {
        var params: [String: String] = [
            "q": query,
            "max": String(options.max),
            "fulltext": "",
        ]
        if let lang = options.lang { params["lang"] = lang }
        if let cat = options.cat { params["cat"] = cat }
        if let notcat = options.notcat { params["notcat"] = notcat }
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

    // MARK: - Browse/Trending

    func trending(max: Int = 50, lang: String? = nil, cat: String? = nil, notcat: String? = nil) async throws -> SearchResponse {
        var params: [String: String] = ["max": String(max)]
        if let lang { params["lang"] = lang }
        if let cat { params["cat"] = cat }
        if let notcat { params["notcat"] = notcat }
        return try await apiRequest(endpoint: "/podcasts/trending", params: params)
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
