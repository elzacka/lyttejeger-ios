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

// MARK: - Certificate Pinning

private final class APIPinningDelegate: NSObject, URLSessionDelegate, Sendable {
    // SHA256 hashes of the SubjectPublicKeyInfo (SPKI) for api.podcastindex.org
    // Leaf = EC P-256, Intermediate = EC P-384.
    // Pinning fails closed: if the API rotates to keys not in this set, all
    // requests are rejected until an app update ships new pins. When adding a
    // pin, compute it with:
    //   openssl s_client -connect api.podcastindex.org:443 -showcerts \
    //     | openssl x509 -pubkey -noout | openssl pkey -pubin -outform DER \
    //     | openssl dgst -sha256 -binary | base64
    private let pinnedKeyHashes: Set<String> = [
        "HKcoICKuDsuKqYvsKrfFMFwTJu4X3mNmNKA/B+1ybho=",
        "brzvtCELCIZUo4sD/qPX0ccRtPsd3DY6RfmxpOU9oB4=",
    ]

    // ASN.1 headers to reconstruct SubjectPublicKeyInfo from raw key data.
    // SecKeyCopyExternalRepresentation returns the raw key (EC) or PKCS#1 (RSA);
    // openssl hashes the full SPKI, so the matching header must be prepended.
    private static let ecP256SPKIHeader: [UInt8] = [
        0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02,
        0x01, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03,
        0x42, 0x00
    ]

    private static let ecP384SPKIHeader: [UInt8] = [
        0x30, 0x76, 0x30, 0x10, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02,
        0x01, 0x06, 0x05, 0x2b, 0x81, 0x04, 0x00, 0x22, 0x03, 0x62, 0x00
    ]

    private static let rsa2048SPKIHeader: [UInt8] = [
        0x30, 0x82, 0x01, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
        0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x0f, 0x00
    ]

    private static let rsa4096SPKIHeader: [UInt8] = [
        0x30, 0x82, 0x02, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
        0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x02, 0x0f, 0x00
    ]

    /// Selects the SPKI header matching the key's type and size, so both EC
    /// and RSA keys in the chain can be evaluated against the pin set.
    private static func spkiHeader(for publicKey: SecKey) -> [UInt8]? {
        guard let attributes = SecKeyCopyAttributes(publicKey) as? [CFString: Any],
              let keyType = attributes[kSecAttrKeyType] as? String,
              let keySize = attributes[kSecAttrKeySizeInBits] as? Int else { return nil }

        if keyType == (kSecAttrKeyTypeECSECPrimeRandom as String) {
            switch keySize {
            case 256: return ecP256SPKIHeader
            case 384: return ecP384SPKIHeader
            default: return nil
            }
        }
        if keyType == (kSecAttrKeyTypeRSA as String) {
            switch keySize {
            case 2048: return rsa2048SPKIHeader
            case 4096: return rsa4096SPKIHeader
            default: return nil
            }
        }
        return nil
    }

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
                  let rawKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as? Data,
                  let spkiHeader = Self.spkiHeader(for: publicKey) else {
                continue
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

actor PodcastIndexAPI: PodcastSearching {
    static let shared = PodcastIndexAPI()

    private let session: URLSession
    private let rateLimiter = RateLimiter(minInterval: AppConstants.podcastIndexRateLimit)
    private var cache = TTLCache<Data>(ttl: AppConstants.apiCacheTTL, maxSize: AppConstants.apiCacheMaxSize)
    private let maxRetries = AppConstants.apiMaxRetries
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config, delegate: APIPinningDelegate(), delegateQueue: nil)
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
                    return try await apiRequest(endpoint: endpoint, params: params, retryCount: retryCount + 1)
                }
                throw PodcastIndexError.rateLimitExceeded

            case 500...599:
                if retryCount < maxRetries {
                    // Exponential backoff: 1s, 2s, 4s for retries 0, 1, 2
                    let delay = AppConstants.apiRetryBaseDelay * pow(2.0, Double(retryCount))
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
