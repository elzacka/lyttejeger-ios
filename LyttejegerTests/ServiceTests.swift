import Foundation
import Testing
import SwiftData
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
    /// Feeds the index knows, keyed by feed URL. Drives OPML import.
    var feedsByUrl: [String: PodcastIndexFeed] = [:]

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
        PodcastByIdResponse(status: "true", feed: feedsByUrl[feedUrl], description: nil)
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
    var feedResults: [String: PodcastFeedResult] = [:]

    struct FeedMissing: Error {}

    func searchCatalog(query: String) async throws -> [Podcast] {
        catalog
    }

    func fetchEpisodes(nrkSlug: String) async throws -> PodcastFeedResult {
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
        chaptersUrl: nil, transcriptUrl: nil, transcripts: nil, soundbite: nil, soundbites: nil,
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
        nrk.feedResults["test_pod"] = PodcastFeedResult(
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
    func firstAcquireImmediate() async throws {
        let limiter = RateLimiter(minInterval: 0.2)
        let clock = ContinuousClock()
        let start = clock.now
        try await limiter.acquire()
        #expect(clock.now - start < .milliseconds(100))
    }

    @Test("a second immediate acquire waits out the interval")
    func secondAcquireWaits() async throws {
        let limiter = RateLimiter(minInterval: 0.2)
        try await limiter.acquire()
        let clock = ContinuousClock()
        let start = clock.now
        try await limiter.acquire()
        #expect(clock.now - start > .milliseconds(120))
    }

    @Test("concurrent acquires are staggered, not burst")
    func concurrentAcquiresStagger() async throws {
        let limiter = RateLimiter(minInterval: 0.15)
        let clock = ContinuousClock()
        let start = clock.now
        async let first: Void = limiter.acquire()
        async let second: Void = limiter.acquire()
        async let third: Void = limiter.acquire()
        _ = try await (first, second, third)
        #expect(clock.now - start > .milliseconds(200))
    }

    @Test("a cancelled acquire throws instead of letting the request through")
    func cancelledAcquireThrows() async throws {
        let limiter = RateLimiter(minInterval: 0.4)
        try await limiter.acquire()

        let waiting = Task { try await limiter.acquire() }
        try await Task.sleep(for: .milliseconds(50))
        waiting.cancel()

        await #expect(throws: CancellationError.self) { try await waiting.value }
    }

    @Test("a cancelled acquire gives its slot back")
    func cancelledAcquireReleasesItsSlot() async throws {
        let limiter = RateLimiter(minInterval: 0.4)
        try await limiter.acquire()

        // Typing past a search cancels it. Before the fix this slot stayed
        // claimed, so the next real request waited out a request that was
        // never sent — roughly a second of dead time per abandoned search.
        let abandoned = Task { try await limiter.acquire() }
        try await Task.sleep(for: .milliseconds(50))
        abandoned.cancel()
        _ = try? await abandoned.value

        let clock = ContinuousClock()
        let start = clock.now
        try await limiter.acquire()
        let waited = clock.now - start

        // One interval from the first acquire, not two.
        #expect(waited < .milliseconds(450))
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

// MARK: - Chapter and transcript fetching (URLProtocol-stubbed)

/// Canned responses keyed by URL. `StubURLProtocol` above keeps one shared
/// handler and needs a `.serialized` suite around it; keying by URL lets the
/// suites below run in parallel with everything else without colliding.
final class URLStub: URLProtocol {
    struct Stubbed {
        var status = 200
        var headers: [String: String] = [:]
        var body = Data()
    }

    private nonisolated(unsafe) static var responses: [String: Stubbed] = [:]
    private nonisolated(unsafe) static var counts: [String: Int] = [:]
    private static let lock = NSLock()

    static func register(_ response: Stubbed, for url: String) {
        lock.lock()
        defer { lock.unlock() }
        responses[url] = response
        counts[url] = 0
    }

    static func unregister(_ url: String) {
        lock.lock()
        defer { lock.unlock() }
        responses[url] = nil
        counts[url] = nil
    }

    /// How many times the network was actually reached — the only way to tell
    /// a cache hit from a second round trip.
    static func requestCount(for url: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return counts[url] ?? 0
    }

    private static func take(_ url: String) -> Stubbed? {
        lock.lock()
        defer { lock.unlock() }
        guard let response = responses[url] else { return nil }
        counts[url, default: 0] += 1
        return response
    }

    private static func has(_ url: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return responses[url] != nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url?.absoluteString else { return false }
        return has(url)
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let stubbed = Self.take(url.absoluteString) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        let response = HTTPURLResponse(
            url: url, statusCode: stubbed.status, httpVersion: "HTTP/1.1", headerFields: stubbed.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stubbed.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func stubbedConfiguration() -> URLSessionConfiguration {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [URLStub.self]
    return config
}

@Suite("ChapterService.fetchChapters")
struct ChapterFetchTests {

    private static let chaptersJSON = Data(#"""
    {"version":"1.2.0","chapters":[{"startTime":0,"title":"Intro"},{"startTime":90,"title":"Tema"}]}
    """#.utf8)

    private func makeService() -> ChapterService {
        ChapterService(configuration: stubbedConfiguration())
    }

    /// Nothing is fetched over plain http, so a downgraded chapter URL can
    /// never pull content into the app.
    @Test("a non-https url is refused without a request")
    func rejectsInsecureURL() async {
        let url = "http://example.com/chapters-\(UUID().uuidString).json"
        URLStub.register(.init(body: Self.chaptersJSON), for: url)
        defer { URLStub.unregister(url) }

        await #expect(throws: ChapterError.self) {
            _ = try await makeService().fetchChapters(from: url)
        }
        #expect(URLStub.requestCount(for: url) == 0)
    }

    @Test("an empty url is refused")
    func rejectsEmptyURL() async {
        await #expect(throws: ChapterError.self) {
            _ = try await makeService().fetchChapters(from: "")
        }
    }

    @Test("a 404 is a failure, not an episode without chapters")
    func mapsNotFoundToFailure() async {
        let url = "https://example.com/chapters-\(UUID().uuidString).json"
        URLStub.register(.init(status: 404), for: url)
        defer { URLStub.unregister(url) }

        await #expect(throws: ChapterError.self) {
            _ = try await makeService().fetchChapters(from: url)
        }
    }

    /// The cap is there so a wrong URL cannot pull an arbitrary payload into
    /// memory on a phone.
    @Test("a payload past the size cap is dropped")
    func rejectsOversizedPayload() async {
        let url = "https://example.com/chapters-\(UUID().uuidString).json"
        let oversized = Data(repeating: UInt8(ascii: " "), count: AppConstants.maxChaptersSize + 1)
        URLStub.register(.init(body: oversized), for: url)
        defer { URLStub.unregister(url) }

        await #expect(throws: ChapterError.self) {
            _ = try await makeService().fetchChapters(from: url)
        }
    }

    /// An error page served with a 200 is the common shape of a dead chapter
    /// URL, and it must not come back as "this episode has no chapters".
    @Test("a 200 that is not a chapters file still fails")
    func rejectsNonChapterBody() async {
        let url = "https://example.com/chapters-\(UUID().uuidString).json"
        URLStub.register(.init(body: Data("<html>Not found</html>".utf8)), for: url)
        defer { URLStub.unregister(url) }

        await #expect(throws: ChapterError.self) {
            _ = try await makeService().fetchChapters(from: url)
        }
    }

    @Test("a good response is parsed and then served from cache")
    func parsesAndCaches() async throws {
        let url = "https://example.com/chapters-\(UUID().uuidString).json"
        URLStub.register(.init(body: Self.chaptersJSON), for: url)
        defer { URLStub.unregister(url) }

        let service = makeService()
        let first = try await service.fetchChapters(from: url)
        let second = try await service.fetchChapters(from: url)

        #expect(first.map(\.title) == ["Intro", "Tema"])
        #expect(second.count == first.count)
        #expect(URLStub.requestCount(for: url) == 1)
    }
}

@Suite("TranscriptService.fetchTranscript")
struct TranscriptFetchTests {

    private static let vtt = Data("""
    WEBVTT

    00:00:00.000 --> 00:00:04.000
    Hei og velkommen.

    00:00:04.000 --> 00:00:08.000
    I dag snakker vi om testing.
    """.utf8)

    private func makeService() -> TranscriptService {
        TranscriptService(configuration: stubbedConfiguration())
    }

    @Test("a non-https url is refused without a request")
    func rejectsInsecureURL() async {
        let url = "http://example.com/transcript-\(UUID().uuidString).vtt"
        URLStub.register(.init(body: Self.vtt), for: url)
        defer { URLStub.unregister(url) }

        await #expect(throws: TranscriptError.self) {
            _ = try await makeService().fetchTranscript(from: url)
        }
        #expect(URLStub.requestCount(for: url) == 0)
    }

    @Test("a server error is a failure the panel can retry")
    func mapsServerErrorToFailure() async {
        let url = "https://example.com/transcript-\(UUID().uuidString).vtt"
        URLStub.register(.init(status: 500), for: url)
        defer { URLStub.unregister(url) }

        await #expect(throws: TranscriptError.self) {
            _ = try await makeService().fetchTranscript(from: url)
        }
    }

    @Test("a payload past the size cap is dropped")
    func rejectsOversizedPayload() async {
        let url = "https://example.com/transcript-\(UUID().uuidString).vtt"
        let oversized = Data(repeating: UInt8(ascii: " "), count: AppConstants.maxTranscriptSize + 1)
        URLStub.register(.init(body: oversized), for: url)
        defer { URLStub.unregister(url) }

        await #expect(throws: TranscriptError.self) {
            _ = try await makeService().fetchTranscript(from: url)
        }
    }

    /// Fetched, read, and nothing usable in it: that is "no transcript", which
    /// the panel states plainly instead of offering a retry that cannot help.
    @Test("a body that is not a transcript comes back empty, not as an error")
    func unreadableBodyIsNoTranscript() async throws {
        let url = "https://example.com/transcript-\(UUID().uuidString).vtt"
        URLStub.register(
            .init(headers: ["Content-Type": "text/html"], body: Data("<html><body>404</body></html>".utf8)),
            for: url
        )
        defer { URLStub.unregister(url) }

        let transcript = try await makeService().fetchTranscript(from: url)
        #expect(transcript == nil)
    }

    @Test("a good response is parsed and then served from cache")
    func parsesAndCaches() async throws {
        let url = "https://example.com/transcript-\(UUID().uuidString).vtt"
        URLStub.register(.init(headers: ["Content-Type": "text/vtt"], body: Self.vtt), for: url)
        defer { URLStub.unregister(url) }

        let service = makeService()
        let first = try await service.fetchTranscript(from: url)
        _ = try await service.fetchTranscript(from: url)

        let transcript = try #require(first)
        #expect(transcript.segments.count == 2)
        #expect(transcript.segments[0].text == "Hei og velkommen.")
        #expect(transcript.isSynced)
        #expect(URLStub.requestCount(for: url) == 1)
    }
}

// MARK: - RSSFeedService

/// Covers the path OPML import depends on: a subscription that Podcast Index
/// does not know keeps only its feed URL, so episodes have to come straight
/// from the feed. Before this existed such a subscription showed no episodes
/// at all, which made import look like it worked while producing dead ends.
@Suite("RSSFeedService")
struct RSSFeedServiceTests {

    private static let feedXML = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>En importert podkast</title>
        <description>Beskrivelse fra feeden</description>
        <item>
          <title>Episode 1</title>
          <description>Om noe</description>
          <guid>ep-1</guid>
          <pubDate>Mon, 06 Jan 2025 08:00:00 +0000</pubDate>
          <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg" length="1000"/>
          <itunes:duration xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">25:00</itunes:duration>
        </item>
      </channel>
    </rss>
    """.utf8)

    private func makeService() -> RSSFeedService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLStub.self]
        return RSSFeedService(configuration: config)
    }

    @Test("reads episodes and channel metadata from an arbitrary feed")
    func readsFeed() async throws {
        let url = "https://example.com/importert.xml"
        URLStub.register(.init(body: Self.feedXML), for: url)
        defer { URLStub.unregister(url) }

        let result = try await makeService().fetchEpisodes(feedUrl: url, podcastId: "feed:\(url)")

        #expect(result.podcastTitle == "En importert podkast")
        #expect(result.episodes.count == 1)
        #expect(result.episodes.first?.title == "Episode 1")
        #expect(result.episodes.first?.podcastId == "feed:\(url)")
    }

    @Test("rejects a non-https feed URL without making a request")
    func rejectsPlainHTTP() async {
        // The URL comes from an imported file, so it is untrusted input and
        // gets the same https-only rule as every other fetch in the app.
        let service = makeService()

        await #expect(throws: RSSFeedService.RSSFeedError.self) {
            try await service.fetchEpisodes(feedUrl: "http://example.com/feed.xml", podcastId: "feed:x")
        }
    }

    @Test("maps a failed fetch to an error instead of an empty feed")
    func mapsFailureToError() async {
        let url = "https://example.com/borte.xml"
        URLStub.register(.init(status: 404), for: url)
        defer { URLStub.unregister(url) }

        await #expect(throws: RSSFeedService.RSSFeedError.self) {
            try await makeService().fetchEpisodes(feedUrl: url, podcastId: "feed:x")
        }
    }

    @Test("serves the second read from cache")
    func cachesFeed() async throws {
        let url = "https://example.com/cachet.xml"
        URLStub.register(.init(body: Self.feedXML), for: url)
        defer { URLStub.unregister(url) }

        let service = makeService()
        _ = try await service.fetchEpisodes(feedUrl: url, podcastId: "feed:x")
        _ = try await service.fetchEpisodes(feedUrl: url, podcastId: "feed:x")

        #expect(URLStub.requestCount(for: url) == 1)
    }
}

// MARK: - Direct-feed podcast ids

@Suite("Podcast.isDirectFeed")
struct DirectFeedPodcastTests {

    private func podcast(id: String) -> Podcast {
        Podcast(
            id: id, title: "T", author: "", description: "", imageUrl: "",
            feedUrl: "", categories: [], language: "Norsk", episodeCount: 0,
            lastUpdated: "", explicit: false
        )
    }

    @Test("recognises a feed: id and returns the URL it carries")
    func recognisesDirectFeed() {
        let p = podcast(id: "feed:https://example.com/a.xml")
        #expect(p.isDirectFeed)
        #expect(p.directFeedUrl == "https://example.com/a.xml")
    }

    @Test("leaves Podcast Index and NRK ids alone")
    func ignoresOtherIdKinds() {
        #expect(!podcast(id: "12345").isDirectFeed)
        #expect(podcast(id: "12345").directFeedUrl == nil)
        #expect(!podcast(id: "nrk:abels_taarn").isDirectFeed)
        #expect(podcast(id: "nrk:abels_taarn").directFeedUrl == nil)
    }
}

// MARK: - OPML import

/// LYT-17: importOPML had no coverage at all, even though it is the path a
/// user migrating from another podcast app takes.
@Suite("DataTransferService.importOPML")
@MainActor
struct ImportOPMLTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([QueueItem.self, Subscription.self, PlaybackPosition.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    private func opml(_ outlines: String) -> Data {
        Data("<opml version=\"2.0\"><body>\(outlines)</body></opml>".utf8)
    }

    private func run(
        _ data: Data,
        context: ModelContext,
        api: MockPodcastSearching = MockPodcastSearching()
    ) async throws -> ImportSummary {
        try await DataTransferService.importOPML(data, into: context, api: api) { _, _ in }
    }

    @Test("resolves a feed the index knows and keeps its metadata")
    func resolvesKnownFeed() async throws {
        let context = try makeContext()
        var api = MockPodcastSearching()
        api.feedsByUrl["https://example.com/42.xml"] = makeFeed(id: 42, title: "Ekte tittel")

        let summary = try await run(
            opml(#"<outline type="rss" text="Fra fila" xmlUrl="https://example.com/42.xml"/>"#),
            context: context, api: api
        )

        #expect(summary.addedSubscriptions == 1)
        let sub = try context.fetch(FetchDescriptor<Subscription>()).first
        #expect(sub?.podcastId == "42")
        #expect(sub?.title == "Ekte tittel")
    }

    @Test("keeps a feed the index does not know, as a direct feed")
    func keepsUnknownFeed() async throws {
        // Dropping it would lose a podcast during a migration. The id carries
        // the feed URL so the episodes can be read straight from the feed.
        let context = try makeContext()

        let summary = try await run(
            opml(#"<outline type="rss" text="Ukjent" xmlUrl="https://example.com/ukjent.xml"/>"#),
            context: context
        )

        #expect(summary.addedSubscriptions == 1)
        let sub = try #require(try context.fetch(FetchDescriptor<Subscription>()).first)
        #expect(sub.podcastId == "feed:https://example.com/ukjent.xml")
        #expect(Podcast(subscription: sub).directFeedUrl == "https://example.com/ukjent.xml")
    }

    @Test("recognises an NRK feed without asking the index")
    func recognisesNRKFeed() async throws {
        let context = try makeContext()

        _ = try await run(
            opml(#"<outline type="rss" text="Abels tårn" xmlUrl="https://sindrel.github.io/nrk-pod-feeds/rss/abels_taarn.xml"/>"#),
            context: context
        )

        let sub = try #require(try context.fetch(FetchDescriptor<Subscription>()).first)
        #expect(sub.podcastId == "nrk:abels_taarn")
        #expect(sub.author == "NRK")
    }

    @Test("skips a feed already followed instead of duplicating it")
    func skipsExisting() async throws {
        let context = try makeContext()
        context.insert(Subscription(
            podcastId: "nrk:abels_taarn", title: "Abels tårn", author: "NRK",
            imageUrl: "", feedUrl: "https://sindrel.github.io/nrk-pod-feeds/rss/abels_taarn.xml"
        ))
        try context.save()

        let summary = try await run(
            opml(#"<outline type="rss" text="Abels tårn" xmlUrl="https://sindrel.github.io/nrk-pod-feeds/rss/abels_taarn.xml"/>"#),
            context: context
        )

        #expect(summary.addedSubscriptions == 0)
        #expect(summary.skippedSubscriptions == 1)
        #expect(try context.fetch(FetchDescriptor<Subscription>()).count == 1)
    }

    @Test("importing the same file twice adds nothing the second time")
    func isIdempotent() async throws {
        let context = try makeContext()
        let file = opml(#"<outline type="rss" text="Ukjent" xmlUrl="https://example.com/a.xml"/>"#)

        _ = try await run(file, context: context)
        let second = try await run(file, context: context)

        #expect(second.addedSubscriptions == 0)
        #expect(try context.fetch(FetchDescriptor<Subscription>()).count == 1)
    }

    @Test("rejects a file with no subscriptions in it")
    func rejectsEmptyFile() async throws {
        let context = try makeContext()

        await #expect(throws: ImportError.self) {
            _ = try await DataTransferService.importOPML(
                self.opml("<outline text='bare en mappe'/>"),
                into: context, api: MockPodcastSearching()
            ) { _, _ in }
        }
    }

    @Test("reports how far it has come, so a long import is not silent")
    func reportsProgress() async throws {
        let context = try makeContext()
        var seen: [Int] = []

        _ = try await DataTransferService.importOPML(
            opml("""
            <outline type="rss" text="A" xmlUrl="https://example.com/a.xml"/>
            <outline type="rss" text="B" xmlUrl="https://example.com/b.xml"/>
            """),
            into: context, api: MockPodcastSearching()
        ) { done, total in
            seen.append(done)
            #expect(total == 2)
        }

        #expect(seen == [1, 2])
    }
}
