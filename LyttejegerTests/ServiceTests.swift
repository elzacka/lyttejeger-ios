import Foundation
import Testing
@testable import Lyttejeger

// MARK: - Service Mocks

/// Value-type mock for `PodcastSearching`. Returns the stored fixtures for
/// every call; a struct is Sendable for free and needs no locking.
struct MockPodcastSearching: PodcastSearching {
    var termFeeds: [PodcastIndexFeed] = []
    var titleFeeds: [PodcastIndexFeed] = []
    var trendingFeeds: [PodcastIndexFeed] = []
    var feedEpisodes: [PodcastIndexEpisode] = []
    var personEpisodes: [PodcastIndexEpisode] = []
    var recentItems: [PodcastIndexEpisode] = []

    func searchByTitle(_ query: String, options: SearchOptions) async throws -> SearchResponse {
        SearchResponse(status: "true", feeds: titleFeeds, count: titleFeeds.count, query: query, description: nil)
    }

    func searchByTerm(_ query: String, options: SearchOptions) async throws -> SearchResponse {
        SearchResponse(status: "true", feeds: termFeeds, count: termFeeds.count, query: query, description: nil)
    }

    func searchByPerson(_ name: String, max: Int) async throws -> EpisodesResponse {
        EpisodesResponse(status: "true", items: personEpisodes, count: personEpisodes.count, description: nil)
    }

    func episodesByFeedId(_ feedId: Int, max: Int, since: Int?) async throws -> EpisodesResponse {
        EpisodesResponse(status: "true", items: feedEpisodes, count: feedEpisodes.count, description: nil)
    }

    func episodesByFeedIds(_ feedIds: [Int], max: Int, since: Int?) async throws -> EpisodesResponse {
        EpisodesResponse(status: "true", items: feedEpisodes, count: feedEpisodes.count, description: nil)
    }

    func podcastByFeedId(_ feedId: Int) async throws -> PodcastByIdResponse {
        PodcastByIdResponse(status: "true", feed: nil, description: nil)
    }

    func podcastByFeedUrl(_ feedUrl: String) async throws -> PodcastByIdResponse {
        PodcastByIdResponse(status: "true", feed: nil, description: nil)
    }

    func trending(max: Int, lang: String?, cat: String?, notcat: String?) async throws -> SearchResponse {
        SearchResponse(status: "true", feeds: trendingFeeds, count: trendingFeeds.count, query: nil, description: nil)
    }

    func recentEpisodes(max: Int, lang: String?) async throws -> EpisodesResponse {
        EpisodesResponse(status: "true", items: recentItems, count: recentItems.count, description: nil)
    }

    var isConfigured: Bool { true }
}

struct MockNRKSearching: NRKSearching {
    var catalog: [Podcast] = []
    var feedResults: [String: NRKFeedResult] = [:]

    struct FeedMissing: Error {}

    func searchCatalog(query: String) async throws -> [Podcast] {
        catalog
    }

    func fetchEpisodes(nrkSlug: String) async throws -> NRKFeedResult {
        guard let result = feedResults[nrkSlug] else { throw FeedMissing() }
        return result
    }
}

// MARK: - Fixtures

func makeFeed(
    id: Int,
    title: String,
    language: String = "en",
    categories: [String: String]? = nil
) -> PodcastIndexFeed {
    PodcastIndexFeed(
        id: id, podcastGuid: nil, title: title,
        url: "https://example.com/\(id).xml", originalUrl: nil, link: nil,
        description: "Beskrivelse", author: "Author", ownerName: nil,
        image: nil, artwork: nil, lastUpdateTime: nil, lastCrawlTime: nil,
        lastParseTime: nil, itunesId: nil, language: language, explicit: false,
        episodeCount: 10, crawlErrors: nil, parseErrors: nil,
        categories: categories, dead: 0
    )
}

func makeApiEpisode(id: Int, feedId: Int?, title: String) -> PodcastIndexEpisode {
    PodcastIndexEpisode(
        id: id, title: title, link: nil, description: "Testbeskrivelse",
        guid: nil, datePublished: 1_700_000_000, datePublishedPretty: nil,
        enclosureUrl: "https://example.com/audio-\(id).mp3", enclosureType: nil,
        enclosureLength: nil, duration: 1800, explicit: 0, episode: nil,
        episodeType: nil, season: nil, image: nil, feedItunesId: nil,
        feedImage: nil, feedId: feedId, feedLanguage: nil, feedDead: nil,
        chaptersUrl: nil, transcriptUrl: nil, soundbite: nil, soundbites: nil,
        feedTitle: "Feed title", feedAuthor: nil
    )
}

func makeNRKPodcast(slug: String = "test_pod", title: String = "Test fra NRK") -> Podcast {
    Podcast(
        id: "nrk:\(slug)", title: title, author: "NRK", description: "",
        imageUrl: "", feedUrl: "https://sindrel.github.io/nrk-pod-feeds/rss/\(slug).xml",
        categories: [], language: "Norsk", episodeCount: 0, lastUpdated: "",
        explicit: false
    )
}

func makeNRKEpisode(id: String, podcastId: String, title: String) -> Episode {
    Episode(
        id: id, podcastId: podcastId, title: title,
        description: "Testbeskrivelse", audioUrl: "https://example.com/\(id).mp3",
        duration: 1800, publishedAt: "", imageUrl: nil, transcriptUrl: nil,
        chaptersUrl: nil, season: nil, episode: nil, episodeType: nil,
        soundbites: nil
    )
}

// MARK: - Browse Dedupe (LYT-12)

@Suite("SearchViewModel.browseEpisodes")
@MainActor
struct BrowseEpisodesDedupeTests {

    @Test("duplicate feed ids from trending do not crash the browse")
    func duplicateFeedIds() async {
        var api = MockPodcastSearching()
        api.trendingFeeds = [
            makeFeed(id: 100, title: "News Daily", categories: ["55": "News"]),
            makeFeed(id: 100, title: "News Daily", categories: ["55": "News"]),
        ]
        api.feedEpisodes = [makeApiEpisode(id: 1, feedId: 100, title: "Episode one")]
        let vm = SearchViewModel(api: api, nrkService: MockNRKSearching())
        vm.filters.categories = ["News"]

        await vm.browseEpisodes()

        #expect(vm.error == nil)
        #expect(vm.episodes.count == 1)
    }

    @Test("unique feed ids browse unchanged")
    func uniqueFeedIds() async {
        var api = MockPodcastSearching()
        api.trendingFeeds = [
            makeFeed(id: 100, title: "News Daily", categories: ["55": "News"]),
            makeFeed(id: 101, title: "News Weekly", categories: ["55": "News"]),
        ]
        api.feedEpisodes = [
            makeApiEpisode(id: 1, feedId: 100, title: "Episode one"),
            makeApiEpisode(id: 2, feedId: 101, title: "Episode two"),
        ]
        let vm = SearchViewModel(api: api, nrkService: MockNRKSearching())
        vm.filters.categories = ["News"]

        await vm.browseEpisodes()

        #expect(vm.error == nil)
        #expect(vm.episodes.count == 2)
    }
}

// MARK: - NRK Filter Merge (LYT-11)

@Suite("SearchViewModel NRK filter merge")
@MainActor
struct NRKFilterMergeTests {

    private func makeViewModel() -> SearchViewModel {
        var api = MockPodcastSearching()
        api.termFeeds = [makeFeed(id: 1, title: "Test Podcast", categories: ["55": "News"])]
        var nrk = MockNRKSearching()
        nrk.catalog = [makeNRKPodcast()]
        return SearchViewModel(api: api, nrkService: nrk)
    }

    @Test("a non-Norwegian language filter excludes NRK results")
    func languageFilterExcludesNRK() async {
        let vm = makeViewModel()
        vm.filters.languages = ["Engelsk"]

        await vm.searchPodcasts("test")

        #expect(vm.podcasts.contains { $0.id == "1" })
        #expect(!vm.podcasts.contains { $0.isNRKFeed })
    }

    @Test("no filter keeps NRK results in the merge")
    func noFilterKeepsNRK() async {
        let vm = makeViewModel()

        await vm.searchPodcasts("test")

        #expect(vm.podcasts.contains { $0.id == "1" })
        #expect(vm.podcasts.contains { $0.isNRKFeed })
    }

    @Test("a category filter excludes category-less NRK results")
    func categoryFilterExcludesNRK() async {
        let vm = makeViewModel()
        vm.filters.categories = ["News"]

        await vm.searchPodcasts("test")

        #expect(vm.podcasts.contains { $0.id == "1" })
        #expect(!vm.podcasts.contains { $0.isNRKFeed })
    }

    @Test("episode search skips NRK when the language filter excludes Norwegian")
    func episodeSearchSkipsNRKOnLanguageFilter() async {
        var nrk = MockNRKSearching()
        nrk.catalog = [makeNRKPodcast()]
        nrk.feedResults["test_pod"] = NRKFeedResult(
            podcastTitle: "Test fra NRK",
            podcastDescription: "",
            podcastImageUrl: "",
            episodes: [makeNRKEpisode(id: "nrk-ep-1", podcastId: "nrk:test_pod", title: "Test episode")]
        )
        let vm = SearchViewModel(api: MockPodcastSearching(), nrkService: nrk)
        vm.filters.languages = ["Engelsk"]

        await vm.searchEpisodes("test")
        #expect(!vm.episodes.contains { $0.episode.id == "nrk-ep-1" })

        // Control: without the filter the same setup surfaces the NRK episode.
        vm.filters.languages = []
        await vm.searchEpisodes("test")
        #expect(vm.episodes.contains { $0.episode.id == "nrk-ep-1" })
    }
}

// MARK: - TTLCache

@Suite("TTLCache")
struct TTLCacheTests {

    @Test("returns the value before expiry")
    func hitBeforeExpiry() {
        var cache = TTLCache<String>(ttl: 60, maxSize: 10)
        cache.insert("verdi", for: "a")
        #expect(cache.value(for: "a") == "verdi")
    }

    @Test("a zero ttl always misses")
    func zeroTTLMisses() {
        var cache = TTLCache<String>(ttl: 0, maxSize: 10)
        cache.insert("verdi", for: "a")
        #expect(cache.value(for: "a") == nil)
    }

    @Test("expires once the ttl has passed")
    func expiresAfterTTL() async throws {
        var cache = TTLCache<String>(ttl: 0.05, maxSize: 10)
        cache.insert("verdi", for: "a")
        try await Task.sleep(for: .milliseconds(150))
        #expect(cache.value(for: "a") == nil)
    }

    @Test("evicts the oldest entries past maxSize")
    func evictsOldest() async throws {
        var cache = TTLCache<Int>(ttl: 60, maxSize: 2)
        cache.insert(1, for: "eldst")
        try await Task.sleep(for: .milliseconds(5))
        cache.insert(2, for: "midt")
        try await Task.sleep(for: .milliseconds(5))
        cache.insert(3, for: "nyest")
        #expect(cache.value(for: "eldst") == nil)
        #expect(cache.value(for: "midt") == 2)
        #expect(cache.value(for: "nyest") == 3)
    }

    @Test("overwriting a key refreshes its timestamp")
    func overwriteRefreshes() async throws {
        var cache = TTLCache<Int>(ttl: 60, maxSize: 2)
        cache.insert(1, for: "a")
        try await Task.sleep(for: .milliseconds(5))
        cache.insert(2, for: "b")
        try await Task.sleep(for: .milliseconds(5))
        cache.insert(10, for: "a")
        try await Task.sleep(for: .milliseconds(5))
        cache.insert(3, for: "c")
        #expect(cache.value(for: "b") == nil)
        #expect(cache.value(for: "a") == 10)
        #expect(cache.value(for: "c") == 3)
    }

    @Test("removeAll empties the cache")
    func removeAll() {
        var cache = TTLCache<String>(ttl: 60, maxSize: 10)
        cache.insert("verdi", for: "a")
        cache.removeAll()
        #expect(cache.value(for: "a") == nil)
    }
}

// MARK: - RateLimiter

@Suite("RateLimiter")
struct RateLimiterTests {

    @Test("the first acquire is immediate")
    func firstAcquireImmediate() async {
        let limiter = RateLimiter(minInterval: 0.2)
        let clock = ContinuousClock()
        let start = clock.now
        await limiter.acquire()
        #expect(clock.now - start < .milliseconds(100))
    }

    @Test("a second immediate acquire waits out the interval")
    func secondAcquireWaits() async {
        let limiter = RateLimiter(minInterval: 0.2)
        await limiter.acquire()
        let clock = ContinuousClock()
        let start = clock.now
        await limiter.acquire()
        #expect(clock.now - start > .milliseconds(120))
    }

    @Test("concurrent acquires are staggered, not burst")
    func concurrentAcquiresStagger() async {
        let limiter = RateLimiter(minInterval: 0.15)
        let clock = ContinuousClock()
        let start = clock.now
        async let first: Void = limiter.acquire()
        async let second: Void = limiter.acquire()
        async let third: Void = limiter.acquire()
        _ = await (first, second, third)
        #expect(clock.now - start > .milliseconds(200))
    }
}

// MARK: - BackgroundRefreshService.splitSubscriptionIds

@Suite("BackgroundRefreshService.splitSubscriptionIds")
struct SplitSubscriptionIdsTests {

    @Test("nrk ids become slugs and numeric ids become feed ids")
    func splitsMixedInput() {
        let (feedIds, slugs) = BackgroundRefreshService.splitSubscriptionIds(
            ["nrk:abels_taarn", "12345", "nrk:ekko", "678"]
        )
        #expect(feedIds == [12345, 678])
        #expect(slugs == ["abels_taarn", "ekko"])
    }

    @Test("feed-prefixed and malformed ids are dropped")
    func dropsUnrefreshableIds() {
        let (feedIds, slugs) = BackgroundRefreshService.splitSubscriptionIds(
            ["feed:https://example.com/rss", "abc", ""]
        )
        #expect(feedIds.isEmpty)
        #expect(slugs.isEmpty)
    }

    @Test("empty input yields empty lists")
    func emptyInput() {
        let (feedIds, slugs) = BackgroundRefreshService.splitSubscriptionIds([])
        #expect(feedIds.isEmpty)
        #expect(slugs.isEmpty)
    }
}

// MARK: - PodcastIndexAPI (URLProtocol-stubbed)

/// Serves canned responses to the API client and records every request.
/// State is static because URLProtocol instances are created by URLSession;
/// the suite below is `.serialized` so tests never share a handler.
final class StubURLProtocol: URLProtocol {
    typealias Handler = @Sendable (Int, URLRequest) -> (Int, [String: String], Data)

    private nonisolated(unsafe) static var handler: Handler?
    private nonisolated(unsafe) static var requests: [URLRequest] = []
    private static let lock = NSLock()

    static func reset(_ newHandler: @escaping Handler) {
        lock.lock()
        defer { lock.unlock() }
        handler = newHandler
        requests = []
    }

    private static func record(_ request: URLRequest) -> (Int, Handler)? {
        lock.lock()
        defer { lock.unlock() }
        guard let handler else { return nil }
        requests.append(request)
        return (requests.count - 1, handler)
    }

    static var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return requests.count
    }

    static var lastRequest: URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return requests.last
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let (index, handler) = Self.record(request) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (status, headers, body) = handler(index, request)
        let response = HTTPURLResponse(
            url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite("PodcastIndexAPI", .serialized)
struct PodcastIndexAPITests {

    private static let emptySearch = Data(#"{"status":"true","feeds":[],"count":0}"#.utf8)
    private static let feedById = Data(#"{"status":"true","feed":{"id":7,"title":"Podden"}}"#.utf8)

    private func makeAPI() -> PodcastIndexAPI {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return PodcastIndexAPI(configuration: config)
    }

    @Test("every request carries the SHA1 auth headers")
    func authHeadersPresent() async throws {
        StubURLProtocol.reset { _, _ in (200, [:], Self.emptySearch) }
        _ = try await makeAPI().searchByTerm("test", options: SearchOptions())

        let request = try #require(StubURLProtocol.lastRequest)
        #expect(request.value(forHTTPHeaderField: "X-Auth-Key") != nil)
        let authDate = try #require(request.value(forHTTPHeaderField: "X-Auth-Date"))
        #expect(Int(authDate) != nil)
        let authorization = try #require(request.value(forHTTPHeaderField: "Authorization"))
        #expect(authorization.count == 40)
        #expect(authorization.allSatisfy { $0.isHexDigit })
        let userAgent = try #require(request.value(forHTTPHeaderField: "User-Agent"))
        #expect(userAgent.hasPrefix("Lyttejeger/"))
    }

    @Test("401 maps to authenticationFailed and 404 to notFound")
    func statusMapping() async throws {
        StubURLProtocol.reset { _, _ in (401, [:], Data()) }
        do {
            _ = try await makeAPI().searchByTerm("x", options: SearchOptions())
            Issue.record("expected authenticationFailed")
        } catch let error as PodcastIndexError {
            guard case .authenticationFailed = error else {
                Issue.record("wrong error: \(error)")
                return
            }
        }

        StubURLProtocol.reset { _, _ in (404, [:], Data()) }
        do {
            _ = try await makeAPI().podcastByFeedId(1)
            Issue.record("expected notFound")
        } catch let error as PodcastIndexError {
            guard case .notFound = error else {
                Issue.record("wrong error: \(error)")
                return
            }
        }
    }

    @Test("429 honors Retry-After and succeeds on the second attempt")
    func retryAfter429() async throws {
        StubURLProtocol.reset { index, _ in
            index == 0 ? (429, ["Retry-After": "0"], Data()) : (200, [:], Self.emptySearch)
        }
        _ = try await makeAPI().searchByTerm("retry", options: SearchOptions())
        #expect(StubURLProtocol.requestCount == 2)
    }

    @Test("a 500 is retried with backoff and succeeds on the second attempt")
    func serverErrorRetries() async throws {
        StubURLProtocol.reset { index, _ in
            index == 0 ? (500, [:], Data()) : (200, [:], Self.emptySearch)
        }
        _ = try await makeAPI().searchByTerm("retry", options: SearchOptions())
        #expect(StubURLProtocol.requestCount == 2)
    }

    @Test("trending with a category does not retry the deterministic 500")
    func trendingCategoryDoesNotRetry() async throws {
        StubURLProtocol.reset { _, _ in (500, [:], Data()) }
        do {
            _ = try await makeAPI().trending(max: 10, lang: nil, cat: "News", notcat: nil)
            Issue.record("expected serverError")
        } catch let error as PodcastIndexError {
            guard case .serverError(500) = error else {
                Issue.record("wrong error: \(error)")
                return
            }
        }
        #expect(StubURLProtocol.requestCount == 1)
    }

    @Test("replays a cached response within the TTL")
    func cacheReplay() async throws {
        StubURLProtocol.reset { index, _ in
            (200, [:], index == 0 ? Self.feedById : Data(#"{"status":"true","feed":{"id":8,"title":"Annen"}}"#.utf8))
        }
        let api = makeAPI()
        let first = try await api.podcastByFeedId(7)
        let second = try await api.podcastByFeedId(7)
        #expect(StubURLProtocol.requestCount == 1)
        #expect(first.feed?.id == 7)
        #expect(second.feed?.id == 7)
    }

    @Test("an undecodable 200 body throws networkError, not a crash")
    func undecodableBodyThrows() async {
        StubURLProtocol.reset { _, _ in (200, [:], Data("ikke json".utf8)) }
        do {
            _ = try await makeAPI().searchByTerm("x", options: SearchOptions())
            Issue.record("expected networkError")
        } catch let error as PodcastIndexError {
            guard case .networkError = error else {
                Issue.record("wrong error: \(error)")
                return
            }
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }
}
