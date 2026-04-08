import Foundation
import Testing
import SwiftData
@testable import Lyttejeger

// MARK: - TimeFormatting Tests

@Suite("formatTime")
struct FormatTimeTests {
    @Test func zero() {
        #expect(formatTime(0) == "0:00")
    }

    @Test func seconds() {
        #expect(formatTime(5) == "0:05")
        #expect(formatTime(59) == "0:59")
    }

    @Test func minutes() {
        #expect(formatTime(60) == "1:00")
        #expect(formatTime(90) == "1:30")
        #expect(formatTime(605) == "10:05")
    }

    @Test func hours() {
        #expect(formatTime(3600) == "1:00:00")
        #expect(formatTime(3661) == "1:01:01")
        #expect(formatTime(7200) == "2:00:00")
    }

    @Test func invalidInput() {
        #expect(formatTime(-1) == "0:00")
        #expect(formatTime(.nan) == "0:00")
        #expect(formatTime(.infinity) == "0:00")
    }
}

@Suite("formatDuration")
struct FormatDurationTests {
    @Test func zero() {
        #expect(formatDuration(0) == "")
    }

    @Test func minutesOnly() {
        #expect(formatDuration(300) == "5 min")
        #expect(formatDuration(2700) == "45 min")
    }

    @Test func hoursAndMinutes() {
        #expect(formatDuration(3600) == "1 t")
        #expect(formatDuration(4980) == "1 t 23 min")
        #expect(formatDuration(7200) == "2 t")
    }
}

// MARK: - SearchQueryParser Tests

@Suite("SearchQueryParser")
struct SearchQueryParserTests {
    @Test func simpleTerms() {
        let result = SearchQueryParser.parse("hello world")
        #expect(result.mustInclude == ["hello", "world"])
        #expect(result.shouldInclude.isEmpty)
        #expect(result.mustExclude.isEmpty)
        #expect(result.exactPhrases.isEmpty)
    }

    @Test func emptyQuery() {
        let result = SearchQueryParser.parse("")
        #expect(result.mustInclude.isEmpty)
    }

    @Test func exactPhrase() {
        let result = SearchQueryParser.parse("\"exact phrase\" other")
        #expect(result.exactPhrases == ["exact phrase"])
        #expect(result.mustInclude == ["other"])
    }

    @Test func exclusion() {
        let result = SearchQueryParser.parse("podcast -news")
        #expect(result.mustInclude == ["podcast"])
        #expect(result.mustExclude == ["news"])
    }

    @Test func orOperator() {
        let result = SearchQueryParser.parse("crime OR mystery")
        #expect(result.shouldInclude.contains("crime"))
        #expect(result.shouldInclude.contains("mystery"))
        #expect(result.mustInclude.isEmpty)
    }

    @Test func smartPunctuation() {
        // iOS replaces " with smart quotes and - with en-dash
        let result = SearchQueryParser.parse("\u{201C}exact\u{201D} \u{2013}exclude")
        #expect(result.exactPhrases == ["exact"])
        #expect(result.mustExclude == ["exclude"])
    }

    @Test func norwegianGuillemets() {
        // Norwegian standard quotation marks « »
        let result = SearchQueryParser.parse("«true crime» other")
        #expect(result.exactPhrases == ["true crime"])
        #expect(result.mustInclude == ["other"])
    }

    @Test func mixedQuotationStyles() {
        // Left guillemet + right smart quote (user inconsistency)
        let result = SearchQueryParser.parse("«true crime\u{201D} other")
        #expect(result.exactPhrases == ["true crime"])
        #expect(result.mustInclude == ["other"])
    }

    @Test func lowNineQuotes() {
        // German/Polish style „phrase"
        let result = SearchQueryParser.parse("\u{201E}exact phrase\u{201D}")
        #expect(result.exactPhrases == ["exact phrase"])
    }

    @Test func caseInsensitiveOr() {
        let lower = SearchQueryParser.parse("crime or mystery")
        #expect(lower.shouldInclude.contains("crime"))
        #expect(lower.shouldInclude.contains("mystery"))
        #expect(lower.mustInclude.isEmpty)

        let mixed = SearchQueryParser.parse("crime Or mystery")
        #expect(mixed.shouldInclude.contains("crime"))
        #expect(mixed.shouldInclude.contains("mystery"))
    }

    @Test func midWordHyphenNotExclusion() {
        // Norwegian compound words and numbers with hyphens
        let result = SearchQueryParser.parse("covid-19 e-post IT-sikkerhet")
        #expect(result.mustInclude == ["covid-19", "e-post", "IT-sikkerhet"])
        #expect(result.mustExclude.isEmpty)
    }

    @Test func exclusionRequiresWordBoundary() {
        // Space before hyphen = exclusion, no space = regular term
        let result = SearchQueryParser.parse("NRK-podkaster -nyheter")
        #expect(result.mustInclude == ["NRK-podkaster"])
        #expect(result.mustExclude == ["nyheter"])
    }
}

// MARK: - PodcastTransform Tests

@Suite("PodcastTransform.htmlToText")
struct HTMLToTextTests {
    @Test func plainText() {
        #expect(PodcastTransform.htmlToText("Hello World") == "Hello World")
    }

    @Test func stripsTags() {
        #expect(PodcastTransform.htmlToText("<b>Bold</b> text") == "Bold text")
    }

    @Test func preservesLinkText() {
        let html = "<a href=\"https://example.com\">Click here</a>"
        #expect(PodcastTransform.htmlToText(html) == "Click here")
    }

    @Test func blockElementsAsNewlines() {
        let html = "<p>Paragraph 1</p><p>Paragraph 2</p>"
        let result = PodcastTransform.htmlToText(html)
        #expect(result.contains("Paragraph 1"))
        #expect(result.contains("Paragraph 2"))
    }

    @Test func decodesHTMLEntities() {
        #expect(PodcastTransform.htmlToText("&amp; &lt; &gt;") == "& < >")
        #expect(PodcastTransform.htmlToText("&aring;&oslash;&aelig;") == "åøæ")
    }

    @Test func decodesNumericEntities() {
        #expect(PodcastTransform.htmlToText("&#65;") == "A")
        #expect(PodcastTransform.htmlToText("&#x41;") == "A")
    }

    @Test func stripsTruncatedTags() {
        let html = "Some text <p data-slate-fragment=\"JTVCZZ"
        #expect(PodcastTransform.htmlToText(html) == "Some text")
    }
}

// MARK: - NRKRSSParser Tests

@Suite("NRKRSSParser.parseDuration")
struct NRKDurationTests {
    @Test func hoursMinutesSeconds() {
        #expect(NRKRSSParser.parseDuration("01:23:45") == 5025)
    }

    @Test func minutesSeconds() {
        #expect(NRKRSSParser.parseDuration("23:45") == 1425)
    }

    @Test func secondsOnly() {
        #expect(NRKRSSParser.parseDuration("120") == 120)
    }

    @Test func empty() {
        #expect(NRKRSSParser.parseDuration("") == 0)
    }
}

// MARK: - formatRelativeDate Tests

@Suite("formatRelativeDate")
struct FormatRelativeDateTests {
    @Test func today() {
        let now = iso8601BasicFormatter.string(from: Date())
        #expect(formatRelativeDate(now) == "I dag")
    }

    @Test func yesterday() {
        let date = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yesterday = iso8601BasicFormatter.string(from: date)
        #expect(formatRelativeDate(yesterday) == "I går")
    }

    @Test func daysAgo() {
        let date = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let threeDaysAgo = iso8601BasicFormatter.string(from: date)
        #expect(formatRelativeDate(threeDaysAgo) == "3 dager siden")
    }

    @Test func weeksAgo() {
        let date = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let tenDaysAgo = iso8601BasicFormatter.string(from: date)
        #expect(formatRelativeDate(tenDaysAgo) == "1 uke siden")
    }

    @Test func invalidDate() {
        #expect(formatRelativeDate("not a date") == "not a date")
    }
}

// MARK: - DurationFilter Tests

@Suite("DurationFilter.matches")
struct DurationFilterTests {
    @Test func under15() {
        #expect(DurationFilter.under15.matches(duration: 600) == true)
        #expect(DurationFilter.under15.matches(duration: 900) == false)
        #expect(DurationFilter.under15.matches(duration: 0) == false)
    }

    @Test func from15to30() {
        #expect(DurationFilter.from15to30.matches(duration: 900) == true)
        #expect(DurationFilter.from15to30.matches(duration: 1200) == true)
        #expect(DurationFilter.from15to30.matches(duration: 1800) == false)
        #expect(DurationFilter.from15to30.matches(duration: 600) == false)
    }

    @Test func from30to60() {
        #expect(DurationFilter.from30to60.matches(duration: 1800) == true)
        #expect(DurationFilter.from30to60.matches(duration: 2700) == true)
        #expect(DurationFilter.from30to60.matches(duration: 3600) == false)
    }

    @Test func over60() {
        #expect(DurationFilter.over60.matches(duration: 3600) == true)
        #expect(DurationFilter.over60.matches(duration: 7200) == true)
        #expect(DurationFilter.over60.matches(duration: 3599) == false)
    }
}

// MARK: - Podcast Model Tests

@Suite("Podcast.isNRKFeed")
struct PodcastNRKTests {
    @Test func nrkFeedDetection() {
        let nrk = Podcast.minimal(id: "nrk:abels_taarn", title: "Abels Tårn", imageUrl: "")
        #expect(nrk.isNRKFeed == true)
        #expect(nrk.nrkSlug == "abels_taarn")
    }

    @Test func nonNRKFeed() {
        let pi = Podcast.minimal(id: "12345", title: "Some Podcast", imageUrl: "")
        #expect(pi.isNRKFeed == false)
        #expect(pi.nrkSlug == nil)
    }

    @Test func minimalFactory() {
        let p = Podcast.minimal(id: "42", title: "Test", imageUrl: "https://example.com/img.jpg")
        #expect(p.id == "42")
        #expect(p.title == "Test")
        #expect(p.imageUrl == "https://example.com/img.jpg")
        #expect(p.author == "")
        #expect(p.description == "")
    }
}

// MARK: - ChapterService.getCurrentChapter Tests

@Suite("ChapterService.getCurrentChapter")
struct GetCurrentChapterTests {
    private let chapters = [
        Chapter(startTime: 0, title: "Intro"),
        Chapter(startTime: 60, title: "Tema"),
        Chapter(startTime: 300, title: "Gjest"),
        Chapter(startTime: 600, title: "Avslutning"),
    ]

    @Test func firstChapter() {
        let result = ChapterService.getCurrentChapter(chapters, at: 30)
        #expect(result?.title == "Intro")
    }

    @Test func middleChapter() {
        let result = ChapterService.getCurrentChapter(chapters, at: 120)
        #expect(result?.title == "Tema")
    }

    @Test func lastChapter() {
        let result = ChapterService.getCurrentChapter(chapters, at: 700)
        #expect(result?.title == "Avslutning")
    }

    @Test func exactBoundary() {
        let result = ChapterService.getCurrentChapter(chapters, at: 300)
        #expect(result?.title == "Gjest")
    }

    @Test func emptyChapters() {
        let result = ChapterService.getCurrentChapter([], at: 100)
        #expect(result == nil)
    }
}

// MARK: - TranscriptService.getCurrentSegment Tests

@Suite("TranscriptService.getCurrentSegment")
struct GetCurrentSegmentTests {
    private let transcript = Transcript(segments: [
        TranscriptSegment(startTime: 0, endTime: 5, text: "Hello"),
        TranscriptSegment(startTime: 5, endTime: 10, text: "World"),
        TranscriptSegment(startTime: 15, endTime: 20, text: "After gap"),
    ])

    @Test func exactMatch() {
        let result = TranscriptService.getCurrentSegment(transcript, at: 2)
        #expect(result?.text == "Hello")
    }

    @Test func secondSegment() {
        let result = TranscriptService.getCurrentSegment(transcript, at: 7)
        #expect(result?.text == "World")
    }

    @Test func inGap() {
        // Between segments (gap at 10-15) — falls back to most recent
        let result = TranscriptService.getCurrentSegment(transcript, at: 12)
        #expect(result?.text == "World")
    }

    @Test func emptyTranscript() {
        let empty = Transcript(segments: [])
        let result = TranscriptService.getCurrentSegment(empty, at: 5)
        #expect(result == nil)
    }
}

// MARK: - NRKRSSParser.parseDate Tests

@Suite("NRKRSSParser.parseDate")
struct NRKParseDateTests {
    @Test func validRFC2822() {
        let result = NRKRSSParser.parseDate("Mon, 15 Jan 2025 12:00:00 +0000")
        #expect(result.contains("2025-01-15"))
    }

    @Test func invalidDate() {
        let result = NRKRSSParser.parseDate("not a date")
        #expect(result == "not a date")
    }
}

// MARK: - PodcastTransform.transformFeed Tests

@Suite("PodcastTransform.transformFeed")
struct TransformFeedTests {
    @Test func basicTransform() {
        let feed = PodcastIndexFeed(
            id: 42,
            podcastGuid: nil,
            title: "Test Pod",
            url: "https://example.com/feed",
            originalUrl: nil,
            link: nil,
            description: "<p>A test podcast</p>",
            author: "Author Name",
            ownerName: nil,
            image: nil,
            artwork: "https://example.com/art.jpg",
            lastUpdateTime: 1700000000,
            lastCrawlTime: nil,
            lastParseTime: nil,
            itunesId: nil,
            language: "no",
            explicit: false,
            episodeCount: 42,
            crawlErrors: nil,
            parseErrors: nil,
            categories: ["9": "Technology"],
            dead: 0
        )
        let podcast = PodcastTransform.transformFeed(feed)
        #expect(podcast.id == "42")
        #expect(podcast.title == "Test Pod")
        #expect(podcast.author == "Author Name")
        #expect(podcast.description == "A test podcast")
        #expect(podcast.imageUrl == "https://example.com/art.jpg")
        #expect(podcast.language == "Norsk")
        #expect(podcast.episodeCount == 42)
        #expect(podcast.explicit == false)
    }

    @Test func deadFeedsFiltered() {
        let feeds = [
            PodcastIndexFeed(
                id: 1, podcastGuid: nil, title: "Live", url: nil, originalUrl: nil,
                link: nil, description: nil, author: nil, ownerName: nil, image: nil,
                artwork: nil, lastUpdateTime: nil, lastCrawlTime: nil, lastParseTime: nil,
                itunesId: nil, language: nil, explicit: nil, episodeCount: nil,
                crawlErrors: nil, parseErrors: nil, categories: nil, dead: 0
            ),
            PodcastIndexFeed(
                id: 2, podcastGuid: nil, title: "Dead", url: nil, originalUrl: nil,
                link: nil, description: nil, author: nil, ownerName: nil, image: nil,
                artwork: nil, lastUpdateTime: nil, lastCrawlTime: nil, lastParseTime: nil,
                itunesId: nil, language: nil, explicit: nil, episodeCount: nil,
                crawlErrors: nil, parseErrors: nil, categories: nil, dead: 1
            ),
        ]
        let result = PodcastTransform.transformFeeds(feeds)
        #expect(result.count == 1)
        #expect(result.first?.title == "Live")
    }
}

// MARK: - QueueViewModel Tests

@Suite("QueueViewModel")
@MainActor
struct QueueViewModelTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([QueueItem.self, Subscription.self, PlaybackPosition.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeEpisode(id: String = "ep-1", title: String = "Test Episode") -> Episode {
        Episode(
            id: id,
            podcastId: "pod-1",
            title: title,
            description: "A test episode",
            audioUrl: "https://example.com/\(id).mp3",
            duration: 1800,
            publishedAt: "20250101T120000Z",
            imageUrl: nil,
            transcriptUrl: nil,
            chaptersUrl: nil,
            season: nil,
            episode: nil,
            episodeType: nil,
            soundbites: nil
        )
    }

    @Test("addToQueue prevents duplicates")
    func addToQueuePreventsduplicates() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = QueueViewModel()
        vm.setup(context)

        let episode = makeEpisode()
        vm.addToQueue(episode: episode, podcastTitle: "Test Podcast", podcastImage: nil)
        vm.addToQueue(episode: episode, podcastTitle: "Test Podcast", podcastImage: nil)

        #expect(vm.items.count == 1)
    }

    @Test("playNext inserts at position 0")
    func playNextInsertsAtPositionZero() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = QueueViewModel()
        vm.setup(context)

        let first = makeEpisode(id: "ep-1", title: "First")
        vm.addToQueue(episode: first, podcastTitle: "Pod", podcastImage: nil)

        let next = makeEpisode(id: "ep-2", title: "Next")
        vm.playNext(episode: next, podcastTitle: "Pod", podcastImage: nil)

        #expect(vm.items.first?.episodeId == "ep-2")
        #expect(vm.items.first?.position == 0)
    }

    @Test("playNext shifts existing items' positions")
    func playNextShiftsExistingItems() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = QueueViewModel()
        vm.setup(context)

        let ep1 = makeEpisode(id: "ep-1")
        let ep2 = makeEpisode(id: "ep-2")
        vm.addToQueue(episode: ep1, podcastTitle: "Pod", podcastImage: nil)
        vm.addToQueue(episode: ep2, podcastTitle: "Pod", podcastImage: nil)

        let front = makeEpisode(id: "ep-front")
        vm.playNext(episode: front, podcastTitle: "Pod", podcastImage: nil)

        #expect(vm.items.count == 3)
        #expect(vm.items[0].episodeId == "ep-front")
        #expect(vm.items[1].position > vm.items[0].position)
        #expect(vm.items[2].position > vm.items[1].position)
    }

    @Test("move reorders items correctly")
    func moveReordersItems() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = QueueViewModel()
        vm.setup(context)

        let ep1 = makeEpisode(id: "ep-1", title: "First")
        let ep2 = makeEpisode(id: "ep-2", title: "Second")
        let ep3 = makeEpisode(id: "ep-3", title: "Third")
        vm.addToQueue(episode: ep1, podcastTitle: "Pod", podcastImage: nil)
        vm.addToQueue(episode: ep2, podcastTitle: "Pod", podcastImage: nil)
        vm.addToQueue(episode: ep3, podcastTitle: "Pod", podcastImage: nil)

        // Move the last item to the front
        vm.move(from: IndexSet(integer: 2), to: 0)

        #expect(vm.items[0].episodeId == "ep-3")
        #expect(vm.items[1].episodeId == "ep-1")
        #expect(vm.items[2].episodeId == "ep-2")
    }

    @Test("clearQueue removes all items")
    func clearQueueRemovesAll() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = QueueViewModel()
        vm.setup(context)

        vm.addToQueue(episode: makeEpisode(id: "ep-1"), podcastTitle: "Pod", podcastImage: nil)
        vm.addToQueue(episode: makeEpisode(id: "ep-2"), podcastTitle: "Pod", podcastImage: nil)
        vm.addToQueue(episode: makeEpisode(id: "ep-3"), podcastTitle: "Pod", podcastImage: nil)

        vm.clearQueue()

        #expect(vm.items.isEmpty)
    }

    @Test("popFirst returns and removes the first item")
    func popFirstReturnsAndRemovesFirst() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = QueueViewModel()
        vm.setup(context)

        let ep1 = makeEpisode(id: "ep-1", title: "First")
        let ep2 = makeEpisode(id: "ep-2", title: "Second")
        vm.addToQueue(episode: ep1, podcastTitle: "Pod", podcastImage: nil)
        vm.addToQueue(episode: ep2, podcastTitle: "Pod", podcastImage: nil)

        let popped = vm.popFirst()

        #expect(popped?.episode.id == "ep-1")
        #expect(vm.items.count == 1)
        #expect(vm.items.first?.episodeId == "ep-2")
    }
}

// MARK: - SubscriptionViewModel Tests

@Suite("SubscriptionViewModel")
@MainActor
struct SubscriptionViewModelTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([QueueItem.self, Subscription.self, PlaybackPosition.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makePodcast(id: String = "pod-1", title: String = "Test Podcast") -> Podcast {
        Podcast(
            id: id, title: title, author: "Test Author", description: "A test podcast",
            imageUrl: "https://example.com/art.jpg", feedUrl: "https://example.com/feed.xml",
            categories: ["Technology"], language: "Norsk", episodeCount: 50,
            lastUpdated: "20250101T000000Z", explicit: false
        )
    }

    @Test("subscribe adds a subscription")
    func subscribeAddsSubscription() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = SubscriptionViewModel()
        vm.setup(context)

        vm.subscribe(podcast: makePodcast())

        #expect(vm.subscriptions.count == 1)
        #expect(vm.subscriptions.first?.podcastId == "pod-1")
    }

    @Test("subscribe is idempotent")
    func subscribeIsIdempotent() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = SubscriptionViewModel()
        vm.setup(context)

        let podcast = makePodcast()
        vm.subscribe(podcast: podcast)
        vm.subscribe(podcast: podcast)

        #expect(vm.subscriptions.count == 1)
    }

    @Test("unsubscribe removes the subscription")
    func unsubscribeRemovesSubscription() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = SubscriptionViewModel()
        vm.setup(context)

        let podcast = makePodcast()
        vm.subscribe(podcast: podcast)
        vm.unsubscribe(podcast.id)

        #expect(vm.subscriptions.isEmpty)
    }

    @Test("toggleSubscription round-trips")
    func toggleSubscriptionRoundTrips() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = SubscriptionViewModel()
        vm.setup(context)

        let podcast = makePodcast()
        vm.toggleSubscription(podcast: podcast)
        #expect(vm.subscriptions.count == 1)

        vm.toggleSubscription(podcast: podcast)
        #expect(vm.subscriptions.isEmpty)
    }

    @Test("isSubscribed returns correct values")
    func isSubscribedReturnsCorrectValues() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = SubscriptionViewModel()
        vm.setup(context)

        #expect(vm.isSubscribed("pod-1") == false)
        vm.subscribe(podcast: makePodcast(id: "pod-1"))
        #expect(vm.isSubscribed("pod-1") == true)
        #expect(vm.isSubscribed("pod-2") == false)
    }
}

// MARK: - Search Ranking Tests

@Suite("SearchViewModel ranking")
@MainActor
struct SearchRankingTests {

    private func makePodcast(
        id: String,
        title: String,
        episodeCount: Int = 10,
        lastUpdated: String = "20250101T000000Z"
    ) -> Podcast {
        Podcast(
            id: id, title: title, author: "", description: "",
            imageUrl: "", feedUrl: "", categories: [],
            language: "Norsk", episodeCount: episodeCount,
            lastUpdated: lastUpdated, explicit: false
        )
    }

    @Test("exact title match scores above prefix match")
    func exactTitleMatchScoresAbovePrefix() {
        let vm = SearchViewModel()
        let exact = makePodcast(id: "1", title: "Daglig Dose")
        let prefix = makePodcast(id: "2", title: "Daglig Dose Ekstra")
        let parsed = SearchQueryParser.parse("daglig dose")

        let ranked = vm.rankResults([prefix, exact], query: "daglig dose", parsed: parsed)

        #expect(ranked.first?.id == "1")
    }

    @Test("dead feeds are penalized")
    func deadFeedsArePenalized() {
        let vm = SearchViewModel()
        let active = makePodcast(id: "1", title: "Norsk Podcast", episodeCount: 50)
        let dead = makePodcast(id: "2", title: "Norsk Podcast", episodeCount: 0)
        let parsed = SearchQueryParser.parse("norsk podcast")

        let ranked = vm.rankResults([dead, active], query: "norsk podcast", parsed: parsed)

        #expect(ranked.first?.id == "1")
    }

    @Test("exclusion operator filters results")
    func exclusionOperatorFiltersResults() {
        let vm = SearchViewModel()
        let podcasts = [
            makePodcast(id: "1", title: "Krim og Mysterier"),
            makePodcast(id: "2", title: "Krim og Nyheter"),
        ]
        let parsed = SearchQueryParser.parse("krim -nyheter")

        let result = vm.applyQueryOperators(podcasts, parsed: parsed)

        #expect(result.count == 1)
        #expect(result.first?.id == "1")
    }

    @Test("exact phrase operator works")
    func exactPhraseOperatorWorks() {
        let vm = SearchViewModel()
        let podcasts = [
            makePodcast(id: "1", title: "Historisk Perspektiv"),
            makePodcast(id: "2", title: "Historisk sett"),
        ]
        let parsed = SearchQueryParser.parse("\"historisk perspektiv\"")

        let result = vm.applyQueryOperators(podcasts, parsed: parsed)

        #expect(result.count == 1)
        #expect(result.first?.id == "1")
    }

    @Test("buildApiQuery returns nil for empty parsed query")
    func buildApiQueryReturnsNilForEmpty() {
        let vm = SearchViewModel()
        let parsed = SearchQueryParser.parse("")

        let result = vm.buildApiQuery(from: parsed)

        #expect(result == nil)
    }

    @Test("buildApiQuery returns nil for exclusion-only query")
    func buildApiQueryReturnsNilForExclusionOnly() {
        let vm = SearchViewModel()
        let parsed = SearchQueryParser.parse("-news")

        let result = vm.buildApiQuery(from: parsed)

        #expect(result == nil)
    }
}

// MARK: - PodcastTransform.transformEpisode Tests

@Suite("PodcastTransform.transformEpisode")
struct TransformEpisodeTests {

    @Test("nil feedId falls back to episode-based id, never '0' or empty string")
    func nilFeedIdProducesFallbackPodcastId() {
        let apiEpisode = PodcastIndexEpisode(
            id: 99,
            title: "Test Episode",
            link: nil,
            description: nil,
            guid: nil,
            datePublished: nil,
            datePublishedPretty: nil,
            enclosureUrl: "https://example.com/ep.mp3",
            enclosureType: nil,
            enclosureLength: nil,
            duration: 1800,
            explicit: 0,
            episode: nil,
            episodeType: nil,
            season: nil,
            image: nil,
            feedItunesId: nil,
            feedImage: nil,
            feedId: nil,
            feedLanguage: nil,
            feedDead: nil,
            chaptersUrl: nil,
            transcriptUrl: nil,
            soundbite: nil,
            soundbites: nil,
            feedTitle: nil,
            feedAuthor: nil
        )

        let episode = PodcastTransform.transformEpisode(apiEpisode)

        // Must never be empty or "0" — both silently break navigation
        #expect(!episode.podcastId.isEmpty)
        #expect(episode.podcastId != "0")
        // With no feedId and no feedTitle, falls back to "unknown:<episodeId>"
        #expect(episode.podcastId == "unknown:99")
    }

    @Test("valid feedId is mapped correctly")
    func validFeedIdIsMapped() {
        let apiEpisode = PodcastIndexEpisode(
            id: 100,
            title: "Episode With Feed",
            link: nil,
            description: nil,
            guid: nil,
            datePublished: nil,
            datePublishedPretty: nil,
            enclosureUrl: "https://example.com/ep.mp3",
            enclosureType: nil,
            enclosureLength: nil,
            duration: 3600,
            explicit: 0,
            episode: nil,
            episodeType: nil,
            season: nil,
            image: nil,
            feedItunesId: nil,
            feedImage: nil,
            feedId: 42,
            feedLanguage: nil,
            feedDead: nil,
            chaptersUrl: nil,
            transcriptUrl: nil,
            soundbite: nil,
            soundbites: nil,
            feedTitle: nil,
            feedAuthor: nil
        )

        let episode = PodcastTransform.transformEpisode(apiEpisode)

        #expect(episode.podcastId == "42")
        #expect(episode.id == "100")
        #expect(episode.duration == 3600)
    }
}
