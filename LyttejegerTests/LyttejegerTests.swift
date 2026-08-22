import Foundation
import Testing
import SwiftData
import UIKit
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

    /// Asserting only that both paragraphs survive passes even when the break
    /// between them is gone — which is the regression this test is named for.
    /// Two paragraphs running into one line is what a stripped `</p>` looks
    /// like in an episode description.
    @Test func blockElementsAsNewlines() {
        let result = PodcastTransform.htmlToText("<p>Paragraph 1</p><p>Paragraph 2</p>")
        #expect(result == "Paragraph 1\nParagraph 2")
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

// MARK: - PodcastRSSParser Tests

@Suite("PodcastRSSParser.parseDuration")
struct NRKDurationTests {
    @Test func hoursMinutesSeconds() {
        #expect(PodcastRSSParser.parseDuration("01:23:45") == 5025)
    }

    @Test func minutesSeconds() {
        #expect(PodcastRSSParser.parseDuration("23:45") == 1425)
    }

    @Test func secondsOnly() {
        #expect(PodcastRSSParser.parseDuration("120") == 120)
    }

    @Test func empty() {
        #expect(PodcastRSSParser.parseDuration("") == 0)
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

// MARK: - PodcastRSSParser.parseDate Tests

@Suite("PodcastRSSParser.parseDate")
struct NRKParseDateTests {
    @Test func validRFC2822() {
        let result = PodcastRSSParser.parseDate("Mon, 15 Jan 2025 12:00:00 +0000")
        #expect(result.contains("2025-01-15"))
    }

    @Test func invalidDate() {
        let result = PodcastRSSParser.parseDate("not a date")
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
            publishedAt: "2025-01-01T12:00:00Z",
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

    @Test("itemAfter advances past the finished episode without removing it")
    func itemAfterAdvancesWithoutRemoving() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = QueueViewModel()
        vm.setup(context)

        vm.addToQueue(episode: makeEpisode(id: "ep-1", title: "First"), podcastTitle: "Pod", podcastImage: nil)
        vm.addToQueue(episode: makeEpisode(id: "ep-2", title: "Second"), podcastTitle: "Pod", podcastImage: nil)

        // The episode that just finished is still first while episodes are
        // kept in the queue, so auto-advance must not hand it back.
        let next = vm.itemAfter(episodeId: "ep-1")

        #expect(next?.episode.id == "ep-2")
        #expect(vm.items.count == 2)
    }

    @Test("itemAfter stops at the end of the queue")
    func itemAfterStopsAtEnd() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = QueueViewModel()
        vm.setup(context)

        vm.addToQueue(episode: makeEpisode(id: "ep-1", title: "Only"), podcastTitle: "Pod", podcastImage: nil)

        #expect(vm.itemAfter(episodeId: "ep-1") == nil)
    }

    @Test("itemAfter starts the queue for an episode played from elsewhere")
    func itemAfterFallsBackToFirst() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = QueueViewModel()
        vm.setup(context)

        vm.addToQueue(episode: makeEpisode(id: "ep-1", title: "First"), podcastTitle: "Pod", podcastImage: nil)

        #expect(vm.itemAfter(episodeId: "not-in-queue")?.episode.id == "ep-1")
        #expect(vm.itemAfter(episodeId: nil)?.episode.id == "ep-1")
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
            lastUpdated: "2025-01-01T00:00:00Z", explicit: false
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

    /// Dates must be extended ISO 8601. `iso8601BasicFormatter` is configured
    /// with default options despite its name, so a compact "20250101T000000Z"
    /// fails to parse, silently becomes .distantPast and disables the freshness
    /// part of the ranking these tests exercise.
    private func makePodcast(
        id: String,
        title: String,
        episodeCount: Int = 10,
        lastUpdated: String = "2025-01-01T00:00:00Z"
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

    @Test("buildApiQueries returns nothing for empty parsed query")
    func buildApiQueriesEmptyForEmptyQuery() {
        let vm = SearchViewModel()
        let parsed = SearchQueryParser.parse("")

        #expect(vm.buildApiQueries(from: parsed).isEmpty)
    }

    @Test("buildApiQueries returns nothing for exclusion-only query")
    func buildApiQueriesEmptyForExclusionOnly() {
        let vm = SearchViewModel()
        let parsed = SearchQueryParser.parse("-news")

        #expect(vm.buildApiQueries(from: parsed).isEmpty)
    }

    @Test("query without OR produces exactly one API query")
    func singleBranchForPlainQuery() {
        let vm = SearchViewModel()
        let parsed = SearchQueryParser.parse("true crime")

        let queries = vm.buildApiQueries(from: parsed)

        #expect(queries == ["true crime"])
    }

    @Test("OR produces one query per alternative instead of collapsing to AND")
    func orProducesOneQueryPerAlternative() {
        let vm = SearchViewModel()
        let parsed = SearchQueryParser.parse("krim OR mystery")

        let queries = vm.buildApiQueries(from: parsed)

        // The API treats spaces as AND, so a single "krim mystery" query would
        // require both terms — the opposite of what OR means.
        #expect(queries.count == 2)
        #expect(queries.contains("krim"))
        #expect(queries.contains("mystery"))
    }

    @Test("required terms are repeated in every OR branch")
    func requiredTermsRepeatInEachBranch() {
        let vm = SearchViewModel()
        // Parses as (krim OR true) AND crime
        let parsed = SearchQueryParser.parse("krim OR true crime")

        let queries = vm.buildApiQueries(from: parsed)

        #expect(queries.count == 2)
        #expect(queries.allSatisfy { $0.contains("crime") })
        #expect(queries.contains { $0.contains("krim") })
        #expect(queries.contains { $0.contains("true") })
    }

    @Test("OR branches are capped so a broad query cannot stall the UI")
    func orBranchesAreCapped() {
        let vm = SearchViewModel()
        let parsed = SearchQueryParser.parse("a1 OR b2 OR c3 OR d4 OR e5")

        let queries = vm.buildApiQueries(from: parsed)

        #expect(queries.count == AppConstants.maxOrBranches)
    }

    @Test("exact phrases are quoted and kept in every branch")
    func exactPhraseIsQuotedInEachBranch() {
        let vm = SearchViewModel()
        let parsed = SearchQueryParser.parse("\"true crime\" krim OR mystery")

        let queries = vm.buildApiQueries(from: parsed)

        #expect(queries.count == 2)
        #expect(queries.allSatisfy { $0.contains("\"true crime\"") })
    }
}

// MARK: - Episode ranking

@Suite("SearchViewModel.rankEpisodes")
@MainActor
struct EpisodeRankingTests {

    /// Dates must be extended ISO 8601, see the note in SearchRankingTests.
    private func makeEpisode(
        id: String,
        title: String,
        description: String = "",
        podcastTitle: String = "En podkast",
        publishedAt: String = "2025-01-01T00:00:00Z"
    ) -> EpisodeWithPodcast {
        EpisodeWithPodcast(
            episode: Episode(
                id: id, podcastId: "p", title: title, description: description,
                audioUrl: "", duration: 0, publishedAt: publishedAt
            ),
            podcast: nil,
            podcastTitle: podcastTitle,
            podcastAuthor: "",
            podcastImage: "",
            feedLanguage: "Norsk"
        )
    }

    @Test("episode title match outranks podcast title match")
    func episodeTitleBeatsPodcastTitle() {
        let vm = SearchViewModel()
        let inPodcastTitle = makeEpisode(id: "1", title: "Ukens gjest", podcastTitle: "Klimapodden")
        let inEpisodeTitle = makeEpisode(id: "2", title: "Klima og kraft", podcastTitle: "Ukeslutt")
        let parsed = SearchQueryParser.parse("klima")

        let ranked = vm.rankEpisodes([inPodcastTitle, inEpisodeTitle], query: "klima", parsed: parsed)

        #expect(ranked.first?.id == "2")
    }

    @Test("title match outranks description match")
    func titleBeatsDescription() {
        let vm = SearchViewModel()
        let inDescription = makeEpisode(id: "1", title: "Ukens gjest", description: "Vi snakker om klima")
        let inTitle = makeEpisode(id: "2", title: "Klima og kraft")
        let parsed = SearchQueryParser.parse("klima")

        let ranked = vm.rankEpisodes([inDescription, inTitle], query: "klima", parsed: parsed)

        #expect(ranked.first?.id == "2")
    }

    @Test("recent episodes outrank old ones when the text match is equal")
    func recencyBreaksTies() {
        let vm = SearchViewModel()
        // Use the app's own formatter: despite the name it is configured with
        // default options, so it reads "2025-01-01T00:00:00Z", not the compact
        // basic format. Hand-written basic-format literals silently fail to
        // parse and collapse to .distantPast.
        let recent = iso8601BasicFormatter.string(from: Date().addingTimeInterval(-2 * 86400))
        let old = iso8601BasicFormatter.string(from: Date().addingTimeInterval(-800 * 86400))

        let oldEpisode = makeEpisode(id: "1", title: "Klima og kraft", publishedAt: old)
        let recentEpisode = makeEpisode(id: "2", title: "Klima og kraft", publishedAt: recent)
        let parsed = SearchQueryParser.parse("klima")

        let ranked = vm.rankEpisodes([oldEpisode, recentEpisode], query: "klima", parsed: parsed)

        #expect(ranked.first?.id == "2")
    }

    @Test("ranking keeps every episode, it only reorders")
    func rankingIsNotAFilter() {
        let vm = SearchViewModel()
        let matching = makeEpisode(id: "1", title: "Klima og kraft")
        let unrelated = makeEpisode(id: "2", title: "Noe helt annet")
        let parsed = SearchQueryParser.parse("klima")

        let ranked = vm.rankEpisodes([matching, unrelated], query: "klima", parsed: parsed)

        #expect(ranked.count == 2)
    }
}

// MARK: - Episode text matching

@Suite("SearchViewModel.episodeMatchesQuery")
@MainActor
struct EpisodeMatchesQueryTests {

    private func makeEpisode(title: String, description: String = "") -> Episode {
        Episode(
            id: "1", podcastId: "p", title: title, description: description,
            audioUrl: "", duration: 0, publishedAt: "2025-01-01T00:00:00Z"
        )
    }

    @Test("requires every plain term to appear in the episode text")
    func requiresAllTerms() {
        let vm = SearchViewModel()
        let parsed = SearchQueryParser.parse("klima kraft")

        #expect(vm.episodeMatchesQuery(makeEpisode(title: "Klima og kraft"), parsed: parsed))
        #expect(!vm.episodeMatchesQuery(makeEpisode(title: "Klima og natur"), parsed: parsed))
    }

    @Test("one OR alternative is enough")
    func orAlternativeIsEnough() {
        let vm = SearchViewModel()
        let parsed = SearchQueryParser.parse("klima OR kraft")

        #expect(vm.episodeMatchesQuery(makeEpisode(title: "Om kraft"), parsed: parsed))
        #expect(!vm.episodeMatchesQuery(makeEpisode(title: "Om noe annet"), parsed: parsed))
    }

    @Test("matches terms found in the description")
    func matchesDescription() {
        let vm = SearchViewModel()
        let parsed = SearchQueryParser.parse("klima")

        #expect(vm.episodeMatchesQuery(
            makeEpisode(title: "Ukens gjest", description: "Vi snakker om klima"),
            parsed: parsed
        ))
    }

    @Test("requires the exact phrase when one is given")
    func requiresExactPhrase() {
        let vm = SearchViewModel()
        let parsed = SearchQueryParser.parse("\"grønn omstilling\"")

        #expect(vm.episodeMatchesQuery(makeEpisode(title: "Om grønn omstilling"), parsed: parsed))
        #expect(!vm.episodeMatchesQuery(makeEpisode(title: "Omstilling som er grønn"), parsed: parsed))
    }
}

// MARK: - OPML

@Suite("OPMLService.parse")
struct OPMLParseTests {

    private func data(_ xml: String) -> Data { Data(xml.utf8) }

    @Test("reads title and feed URL from a standard export")
    func readsStandardExport() {
        let entries = OPMLService.parse(data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
          <body>
            <outline type="rss" text="Abels tårn" xmlUrl="https://example.com/abels.xml"/>
          </body>
        </opml>
        """))

        #expect(entries == [OPMLEntry(title: "Abels tårn", feedUrl: "https://example.com/abels.xml")])
    }

    @Test("prefers title over text when both are present")
    func prefersTitleAttribute() {
        let entries = OPMLService.parse(data("""
        <opml><body>
          <outline type="rss" text="fallback" title="Ekte tittel" xmlUrl="https://example.com/a.xml"/>
        </body></opml>
        """))

        #expect(entries.first?.title == "Ekte tittel")
    }

    @Test("finds feeds nested inside category folders")
    func findsNestedFeeds() {
        // Apple Podcasts and Pocket Casts both group subscriptions this way
        let entries = OPMLService.parse(data("""
        <opml><body>
          <outline text="Krim">
            <outline type="rss" text="En podkast" xmlUrl="https://example.com/a.xml"/>
          </outline>
        </body></opml>
        """))

        #expect(entries.count == 1)
        #expect(entries.first?.feedUrl == "https://example.com/a.xml")
    }

    @Test("skips outlines without a feed URL")
    func skipsFolders() {
        let entries = OPMLService.parse(data("""
        <opml><body>
          <outline text="Bare en mappe"/>
          <outline type="rss" text="Ekte" xmlUrl="https://example.com/a.xml"/>
        </body></opml>
        """))

        #expect(entries.count == 1)
    }

    @Test("handles lowercase attribute spelling")
    func handlesLowercaseAttributes() {
        let entries = OPMLService.parse(data("""
        <opml><body><outline type="rss" text="A" xmlurl="https://example.com/a.xml"/></body></opml>
        """))

        #expect(entries.count == 1)
    }

    @Test("drops duplicate feed URLs")
    func dropsDuplicates() {
        let entries = OPMLService.parse(data("""
        <opml><body>
          <outline type="rss" text="A" xmlUrl="https://example.com/a.xml"/>
          <outline type="rss" text="A igjen" xmlUrl="https://example.com/a.xml"/>
        </body></opml>
        """))

        #expect(entries.count == 1)
    }

    @Test("returns nothing for a file that is not OPML")
    func rejectsNonOPML() {
        #expect(OPMLService.parse(data("<rss><channel><title>Noe</title></channel></rss>")).isEmpty)
    }
}

@Suite("OPMLService.makeDocument")
struct OPMLExportTests {

    private func subscription(title: String, feedUrl: String) -> Subscription {
        Subscription(
            podcastId: "1", title: title, author: "", imageUrl: "", feedUrl: feedUrl
        )
    }

    @Test("round-trips through the parser")
    func roundTrips() {
        let subs = [
            subscription(title: "Abels tårn", feedUrl: "https://example.com/abels.xml"),
            subscription(title: "Ekko", feedUrl: "https://example.com/ekko.xml"),
        ]

        let document = OPMLService.makeDocument(from: subs, generatedAt: Date())
        let parsed = OPMLService.parse(Data(document.utf8))

        #expect(parsed.count == 2)
        #expect(parsed.map(\.title) == ["Abels tårn", "Ekko"])
    }

    @Test("escapes characters that would break the XML")
    func escapesSpecialCharacters() {
        let subs = [subscription(title: "Ludvig & \"Co\" <live>", feedUrl: "https://example.com/a.xml?x=1&y=2")]

        let document = OPMLService.makeDocument(from: subs, generatedAt: Date())

        #expect(!document.contains("& "))
        #expect(document.contains("&amp;"))

        // The real check: it must survive a parse unchanged
        let parsed = OPMLService.parse(Data(document.utf8))
        #expect(parsed.first?.title == "Ludvig & \"Co\" <live>")
        #expect(parsed.first?.feedUrl == "https://example.com/a.xml?x=1&y=2")
    }

    @Test("leaves out subscriptions with no feed URL")
    func skipsSubscriptionsWithoutFeed() {
        let subs = [
            subscription(title: "Uten feed", feedUrl: ""),
            subscription(title: "Med feed", feedUrl: "https://example.com/a.xml"),
        ]

        let parsed = OPMLService.parse(Data(OPMLService.makeDocument(from: subs, generatedAt: Date()).utf8))

        #expect(parsed.count == 1)
        #expect(parsed.first?.title == "Med feed")
    }
}

@Suite("DataTransferService format detection")
struct DataTransferFormatTests {

    @Test("uses the file extension when it is known")
    func usesExtension() {
        let url = URL(fileURLWithPath: "/tmp/abonnementer.opml")
        #expect(DataTransferService.detectFormat(url: url, data: Data("<opml/>".utf8)) == .opml)
    }

    @Test("sniffs the contents when the extension is generic")
    func sniffsContents() {
        // Several podcast apps export OPML named .xml
        let xml = URL(fileURLWithPath: "/tmp/export.xml")
        #expect(DataTransferService.detectFormat(url: xml, data: Data("<?xml version=\"1.0\"?><opml/>".utf8)) == .opml)

        let unknown = URL(fileURLWithPath: "/tmp/backup.txt")
        #expect(DataTransferService.detectFormat(url: unknown, data: Data("{\"app\":\"Lyttejeger\"}".utf8)) == .json)
    }

    @Test("returns nothing for an unrecognised file")
    func rejectsUnknown() {
        let url = URL(fileURLWithPath: "/tmp/noe.bin")
        #expect(DataTransferService.detectFormat(url: url, data: Data("bare tekst".utf8)) == nil)
    }
}

@Suite("DataTransferService.importJSON")
@MainActor
struct ImportJSONTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([QueueItem.self, Subscription.self, PlaybackPosition.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    private func backup(
        subscriptions: [[String: Any]] = [],
        queue: [[String: Any]] = [],
        positions: [[String: Any]] = []
    ) -> Data {
        try! JSONSerialization.data(withJSONObject: [
            "app": "Lyttejeger",
            "abonnementer": subscriptions,
            "spillekø": queue,
            "avspillingsposisjoner": positions,
        ])
    }

    @Test("adds subscriptions, queue items and positions")
    func addsEverything() throws {
        let context = try makeContext()
        let data = backup(
            subscriptions: [["podcastId": "1", "tittel": "En podkast", "feedUrl": "https://a.xml"]],
            queue: [["episodeId": "e1", "tittel": "Ep", "audioUrl": "https://a.mp3"]],
            positions: [["episodeId": "e1", "posisjon": 42.0, "varighet": 100.0]]
        )

        let summary = try DataTransferService.importJSON(data, into: context)

        #expect(summary.addedSubscriptions == 1)
        #expect(summary.addedQueueItems == 1)
        #expect(summary.addedPositions == 1)
        #expect(try context.fetch(FetchDescriptor<Subscription>()).count == 1)
    }

    @Test("merges instead of replacing, so existing data survives")
    func mergesRatherThanReplaces() throws {
        let context = try makeContext()
        context.insert(Subscription(
            podcastId: "existing", title: "Fra før", author: "", imageUrl: "", feedUrl: "https://b.xml"
        ))
        try context.save()

        _ = try DataTransferService.importJSON(
            backup(subscriptions: [["podcastId": "1", "tittel": "Ny", "feedUrl": "https://a.xml"]]),
            into: context
        )

        let ids = try context.fetch(FetchDescriptor<Subscription>()).map(\.podcastId).sorted()
        #expect(ids == ["1", "existing"])
    }

    @Test("importing the same file twice changes nothing the second time")
    func isIdempotent() throws {
        let context = try makeContext()
        let data = backup(
            subscriptions: [["podcastId": "1", "tittel": "En podkast", "feedUrl": "https://a.xml"]],
            queue: [["episodeId": "e1", "tittel": "Ep", "audioUrl": "https://a.mp3"]]
        )

        _ = try DataTransferService.importJSON(data, into: context)
        let second = try DataTransferService.importJSON(data, into: context)

        #expect(second.addedSubscriptions == 0)
        #expect(second.addedQueueItems == 0)
        #expect(second.skippedSubscriptions == 1)
        #expect(try context.fetch(FetchDescriptor<Subscription>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<QueueItem>()).count == 1)
    }

    @Test("imported queue items go after the existing queue")
    func appendsToQueue() throws {
        let context = try makeContext()
        context.insert(QueueItem(
            episodeId: "old", podcastId: "p", title: "Gammel",
            podcastTitle: "P", audioUrl: "https://old.mp3", position: 0
        ))
        try context.save()

        _ = try DataTransferService.importJSON(
            backup(queue: [["episodeId": "new", "tittel": "Ny", "audioUrl": "https://new.mp3"]]),
            into: context
        )

        let items = try context.fetch(FetchDescriptor<QueueItem>(sortBy: [SortDescriptor(\.position)]))
        #expect(items.map(\.episodeId) == ["old", "new"])
    }

    @Test("skips entries missing the fields they need")
    func skipsIncompleteEntries() throws {
        let context = try makeContext()

        let summary = try DataTransferService.importJSON(
            backup(
                subscriptions: [["tittel": "Uten id"]],
                queue: [["episodeId": "e1", "tittel": "Uten lyd"]]
            ),
            into: context
        )

        #expect(summary.addedSubscriptions == 0)
        #expect(summary.addedQueueItems == 0)
    }

    @Test("restores the settings a backup carries")
    func restoresSettings() throws {
        // LYT-24: settings were exported but never read back, so the documented
        // round-trip did not exist.
        let context = try makeContext()
        UserDefaults.standard.set(true, forKey: AppConstants.showLastPlayedKey)
        UserDefaults.standard.set(false, forKey: AppConstants.keepEpisodesInQueueKey)
        defer {
            UserDefaults.standard.removeObject(forKey: AppConstants.showLastPlayedKey)
            UserDefaults.standard.removeObject(forKey: AppConstants.keepEpisodesInQueueKey)
        }

        let data = try! JSONSerialization.data(withJSONObject: [
            "abonnementer": [],
            "innstillinger": [
                "visFortsettÅLytte": false,
                "beholdEpisoderIKoen": true,
            ],
        ])
        _ = try DataTransferService.importJSON(data, into: context)

        #expect(UserDefaults.standard.bool(forKey: AppConstants.showLastPlayedKey) == false)
        #expect(UserDefaults.standard.bool(forKey: AppConstants.keepEpisodesInQueueKey) == true)
    }

    @Test("leaves a setting the backup does not mention alone")
    func leavesUnknownSettingAlone() throws {
        // An older export predates a setting; that must not reset it.
        let context = try makeContext()
        UserDefaults.standard.set(true, forKey: AppConstants.keepEpisodesInQueueKey)
        defer { UserDefaults.standard.removeObject(forKey: AppConstants.keepEpisodesInQueueKey) }

        let data = try! JSONSerialization.data(withJSONObject: [
            "abonnementer": [],
            "innstillinger": ["visFortsettÅLytte": true],
        ])
        _ = try DataTransferService.importJSON(data, into: context)

        #expect(UserDefaults.standard.bool(forKey: AppConstants.keepEpisodesInQueueKey) == true)
    }

    @Test("counts a podcast listed twice in one file only once")
    func dedupesWithinFile() throws {
        // LYT-25: the unique constraint stored one row while the summary
        // claimed two additions, so the user was told the wrong thing.
        let context = try makeContext()

        let summary = try DataTransferService.importJSON(
            backup(subscriptions: [
                ["podcastId": "1", "tittel": "En podkast", "feedUrl": "https://a.xml"],
                ["podcastId": "1", "tittel": "Samme podkast", "feedUrl": "https://a.xml"],
            ]),
            into: context
        )

        #expect(summary.addedSubscriptions == 1)
        #expect(summary.skippedSubscriptions == 1)
        #expect(try context.fetch(FetchDescriptor<Subscription>()).count == 1)
    }

    @Test("rejects a JSON file that is not a Lyttejeger backup")
    func rejectsForeignJSON() throws {
        let context = try makeContext()
        let data = try! JSONSerialization.data(withJSONObject: ["noe": "helt annet"])

        #expect(throws: ImportError.self) {
            try DataTransferService.importJSON(data, into: context)
        }
    }
}

@Suite("DataTransferService JSON round-trip")
@MainActor
struct JSONRoundTripTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([QueueItem.self, Subscription.self, PlaybackPosition.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    @Test("every QueueItem field survives export and import")
    func queueItemFieldsSurvive() throws {
        let source = try makeContext()
        // Whole seconds: the backup's ISO 8601 formatter has no fractional
        // seconds, so dates with sub-second parts cannot round-trip exactly.
        let added = Date(timeIntervalSince1970: 1_700_000_000)
        let subscribed = Date(timeIntervalSince1970: 1_690_000_000)
        let updated = Date(timeIntervalSince1970: 1_695_000_000)

        source.insert(Subscription(
            podcastId: "42", title: "Podden", author: "Forfatter",
            imageUrl: "https://example.com/pod.jpg", feedUrl: "https://example.com/feed.xml",
            subscribedAt: subscribed
        ))
        source.insert(QueueItem(
            episodeId: "e1", podcastId: "42", title: "Episode en",
            episodeDescription: "Full beskrivelse",
            podcastTitle: "Podden", audioUrl: "https://example.com/e1.mp3",
            imageUrl: "https://example.com/e1.jpg",
            podcastImage: "https://example.com/pod.jpg",
            duration: 1234,
            transcriptUrl: "https://example.com/e1.vtt",
            chaptersUrl: "https://example.com/e1.json",
            publishedAt: "2026-08-01T10:00:00Z",
            season: 2, episode: 7,
            addedAt: added, position: 0
        ))
        source.insert(QueueItem(
            episodeId: "e2", podcastId: "42", title: "Episode to",
            podcastTitle: "Podden", audioUrl: "https://example.com/e2.mp3",
            position: 1
        ))
        source.insert(PlaybackPosition(
            episodeId: "e1", position: 600, duration: 1234,
            updatedAt: updated, completed: false
        ))
        try source.save()

        let data = try DataTransferService.makeJSONExport(
            subscriptions: try source.fetch(FetchDescriptor<Subscription>()),
            queueItems: try source.fetch(FetchDescriptor<QueueItem>(sortBy: [SortDescriptor(\.position)])),
            positions: try source.fetch(FetchDescriptor<PlaybackPosition>()),
            exportedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )

        let target = try makeContext()
        let summary = try DataTransferService.importJSON(data, into: target)
        #expect(summary.addedSubscriptions == 1)
        #expect(summary.addedQueueItems == 2)
        #expect(summary.addedPositions == 1)

        let items = try target.fetch(FetchDescriptor<QueueItem>(sortBy: [SortDescriptor(\.position)]))
        #expect(items.map(\.episodeId) == ["e1", "e2"])

        let e1 = try #require(items.first)
        #expect(e1.podcastId == "42")
        #expect(e1.title == "Episode en")
        #expect(e1.episodeDescription == "Full beskrivelse")
        #expect(e1.podcastTitle == "Podden")
        #expect(e1.audioUrl == "https://example.com/e1.mp3")
        #expect(e1.imageUrl == "https://example.com/e1.jpg")
        #expect(e1.podcastImage == "https://example.com/pod.jpg")
        #expect(e1.duration == 1234)
        #expect(e1.transcriptUrl == "https://example.com/e1.vtt")
        #expect(e1.chaptersUrl == "https://example.com/e1.json")
        #expect(e1.publishedAt == "2026-08-01T10:00:00Z")
        #expect(e1.season == 2)
        #expect(e1.episode == 7)
        #expect(e1.addedAt == added)

        let sub = try #require(try target.fetch(FetchDescriptor<Subscription>()).first)
        #expect(sub.subscribedAt == subscribed)
        let pos = try #require(try target.fetch(FetchDescriptor<PlaybackPosition>()).first)
        #expect(pos.position == 600)
        #expect(pos.updatedAt == updated)
    }

    @Test("a legacy backup without the new queue fields still imports")
    func legacyBackupImports() throws {
        let context = try makeContext()
        let data = try! JSONSerialization.data(withJSONObject: [
            "app": "Lyttejeger",
            "spillekø": [[
                "episodeId": "e1", "podcastId": "42", "tittel": "Gammel episode",
                "podkast": "Podden", "audioUrl": "https://example.com/e1.mp3",
                "posisjon": 0,
            ] as [String: Any]],
        ])

        let summary = try DataTransferService.importJSON(data, into: context)

        #expect(summary.addedQueueItems == 1)
        let item = try #require(try context.fetch(FetchDescriptor<QueueItem>()).first)
        #expect(item.episodeDescription == nil)
        #expect(item.duration == nil)
        #expect(item.season == nil)
    }
}

@Suite("DataTransferService.deleteAllUserData")
@MainActor
struct DeleteAllUserDataTests {

    @Test("removes every stored model")
    func removesEverything() throws {
        let schema = Schema([QueueItem.self, Subscription.self, PlaybackPosition.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let context = ModelContext(try ModelContainer(for: schema, configurations: [config]))
        context.insert(Subscription(
            podcastId: "1", title: "P", author: "", imageUrl: "", feedUrl: "https://a.xml"
        ))
        context.insert(QueueItem(
            episodeId: "e1", podcastId: "1", title: "E", podcastTitle: "P",
            audioUrl: "https://a.mp3", position: 0
        ))
        context.insert(PlaybackPosition(episodeId: "e1", position: 10, duration: 100))
        try context.save()

        try DataTransferService.deleteAllUserData(in: context)

        #expect(try context.fetch(FetchDescriptor<Subscription>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<QueueItem>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PlaybackPosition>()).isEmpty)
    }
}

@Suite("DataTransferService.nrkSlug")
struct NRKSlugFromFeedUrlTests {

    @Test("recognises an NRK feed URL")
    func recognisesNRKFeed() {
        #expect(DataTransferService.nrkSlug(
            fromFeedUrl: "https://sindrel.github.io/nrk-pod-feeds/rss/abels_taarn.xml"
        ) == "abels_taarn")
    }

    @Test("ignores unrelated feed URLs")
    func ignoresOtherFeeds() {
        #expect(DataTransferService.nrkSlug(fromFeedUrl: "https://example.com/feed.xml") == nil)
    }

    @Test("rejects a slug with unsafe characters")
    func rejectsUnsafeSlug() {
        // Guards the same path-traversal case the feed fetcher guards
        #expect(DataTransferService.nrkSlug(
            fromFeedUrl: "https://sindrel.github.io/nrk-pod-feeds/rss/../../etc/passwd.xml"
        ) == nil)
    }
}

// MARK: - NRK catalog tokenisation

@Suite("NRKPodcastService.searchTokens")
struct NRKSearchTokensTests {

    @Test("splits a query into separate words")
    func splitsIntoWords() {
        #expect(NRKPodcastService.searchTokens(from: "Abels tårn") == ["abels", "tårn"])
    }

    @Test("word order no longer decides the outcome")
    func orderIndependent() {
        let forward = NRKPodcastService.searchTokens(from: "abels tårn")
        let reversed = NRKPodcastService.searchTokens(from: "tårn abels")

        // Both token sets must match the same title, which the old raw
        // substring match could not do.
        let title = "abels tårn"
        #expect(forward.allSatisfy { title.contains($0) })
        #expect(reversed.allSatisfy { title.contains($0) })
    }

    @Test("strips the quotes an exact phrase still carries")
    func stripsQuotes() {
        #expect(NRKPodcastService.searchTokens(from: "\"abels tårn\"") == ["abels", "tårn"])
    }

    @Test("collapses extra whitespace")
    func collapsesWhitespace() {
        #expect(NRKPodcastService.searchTokens(from: "  abels   tårn  ") == ["abels", "tårn"])
    }
}

// MARK: - Word-boundary matching

@Suite("SearchQueryParser.containsTerm")
struct ContainsTermTests {

    @Test("matches a standalone word")
    func matchesStandaloneWord() {
        #expect(SearchQueryParser.containsTerm("krim", in: "en podkast om krim og drama"))
    }

    @Test("matches at the start of the text")
    func matchesAtStart() {
        #expect(SearchQueryParser.containsTerm("krim", in: "krim og drama"))
    }

    @Test("does not match a substring inside a longer word")
    func rejectsSubstringInsideWord() {
        // The bug this replaced: `-app` discarded every result mentioning
        // "rapport", because "rapport" contains "app".
        #expect(!SearchQueryParser.containsTerm("app", in: "en grundig rapport"))
    }

    @Test("still matches inflected forms")
    func matchesInflectedForms() {
        // Boundary is required before the match but not after, so Norwegian
        // inflection keeps working.
        #expect(SearchQueryParser.containsTerm("mord", in: "mordet ble oppklart"))
    }

    @Test("phrase does not match across a word boundary violation")
    func phraseRejectsPartialWordStart() {
        #expect(!SearchQueryParser.containsTerm("true crime", in: "construe crime"))
        #expect(SearchQueryParser.containsTerm("true crime", in: "a true crime story"))
    }

    @Test("handles Norwegian letters as word characters")
    func handlesNorwegianLetters() {
        // "året" must not be treated as a boundary before "ret"
        #expect(!SearchQueryParser.containsTerm("ret", in: "året som gikk"))
        #expect(SearchQueryParser.containsTerm("året", in: "året som gikk"))
    }

    @Test("empty needle never matches")
    func emptyNeedleNeverMatches() {
        #expect(!SearchQueryParser.containsTerm("", in: "noe tekst"))
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
            transcripts: nil,
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
            transcripts: nil,
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

// MARK: - Category filter

@Suite("SearchViewModel.filterByCategory")
@MainActor
struct CategoryFilterTests {

    private func makePodcast(categories: [String]) -> Podcast {
        Podcast(
            id: "1", title: "Test", author: "", description: "",
            imageUrl: "", feedUrl: "", categories: categories,
            language: "Norsk", episodeCount: 10,
            lastUpdated: "2025-01-01T00:00:00Z", explicit: false
        )
    }

    /// `/categories/list` spells it with a hyphen, a feed spells it with a
    /// space. Matching the two literally discarded every result.
    @Test("hyphenated filter matches the spaced name a feed reports")
    func hyphenMatchesSpace() {
        let vm = SearchViewModel()
        vm.filters.categories = ["Self-Improvement"]

        let matching = vm.filterByCategory([makePodcast(categories: ["Health", "Self Improvement"])])

        #expect(matching.count == 1)
    }

    @Test("the same holds for the other affected categories")
    func hyphenMatchesSpaceForAllAffected() {
        let cases = [
            ("Video-Games", "Video Games"),
            ("How-To", "How To"),
            ("Role-Playing", "Role Playing"),
        ]

        for (filter, reported) in cases {
            let vm = SearchViewModel()
            vm.filters.categories = [filter]
            let matching = vm.filterByCategory([makePodcast(categories: [reported])])
            #expect(matching.count == 1, "\(filter) should match \(reported)")
        }
    }

    @Test("categories spelled the same way still match")
    func unaffectedCategoriesStillMatch() {
        let vm = SearchViewModel()
        vm.filters.categories = ["After-Shows"]

        let matching = vm.filterByCategory([makePodcast(categories: ["After-Shows"])])

        #expect(matching.count == 1)
    }

    @Test("an unrelated category is still filtered out")
    func unrelatedCategoryIsExcluded() {
        let vm = SearchViewModel()
        vm.filters.categories = ["Self-Improvement"]

        let matching = vm.filterByCategory([makePodcast(categories: ["News", "Politics"])])

        #expect(matching.isEmpty)
    }

    @Test("no category filter lets everything through")
    func noFilterPassesEverything() {
        let vm = SearchViewModel()
        let all = vm.filterByCategory([makePodcast(categories: ["News"])])
        #expect(all.count == 1)
    }
}

// MARK: - Episode de-duplication

@Suite("SearchViewModel.episodeDedupeKey")
@MainActor
struct EpisodeDedupeTests {

    private func makeEpisode(id: String, audioUrl: String) -> Episode {
        Episode(
            id: id, podcastId: "1", title: "Operation Candy",
            description: "", audioUrl: audioUrl, duration: 1560,
            publishedAt: "2025-01-01T00:00:00Z"
        )
    }

    /// The same audio indexed under two feeds gets two episode ids, which is
    /// how a duplicate reached the results list.
    @Test("same audio under different ids collapses to one key")
    func sameAudioSameKey() {
        let vm = SearchViewModel()
        let a = makeEpisode(id: "100", audioUrl: "https://cdn.example/candy.mp3")
        let b = makeEpisode(id: "200", audioUrl: "https://cdn.example/candy.mp3")

        #expect(vm.episodeDedupeKey(a) == vm.episodeDedupeKey(b))
    }

    @Test("different audio stays distinct")
    func differentAudioDifferentKey() {
        let vm = SearchViewModel()
        let a = makeEpisode(id: "100", audioUrl: "https://cdn.example/one.mp3")
        let b = makeEpisode(id: "100", audioUrl: "https://cdn.example/two.mp3")

        #expect(vm.episodeDedupeKey(a) != vm.episodeDedupeKey(b))
    }

    @Test("episodes without audio fall back to the id")
    func missingAudioFallsBackToId() {
        let vm = SearchViewModel()
        let a = makeEpisode(id: "100", audioUrl: "")
        let b = makeEpisode(id: "200", audioUrl: "")

        #expect(vm.episodeDedupeKey(a) == "100")
        #expect(vm.episodeDedupeKey(a) != vm.episodeDedupeKey(b))
    }
}

// MARK: - Clearing filters

@Suite("SearchViewModel.clearFilters")
@MainActor
struct ClearFiltersTests {

    /// The button sits under "Aktive filter", so it must not throw away what
    /// the user typed.
    @Test("the query survives clearing the filters")
    func queryIsPreserved() {
        let vm = SearchViewModel()
        vm.filters.query = "krim"
        vm.filters.categories = ["Documentary"]
        vm.filters.languages = ["Norsk"]
        vm.filters.sortBy = .newest

        vm.clearFilters()

        #expect(vm.filters.query == "krim")
        #expect(vm.filters.categories.isEmpty)
        #expect(vm.filters.languages.isEmpty)
        #expect(vm.filters.sortBy == .relevance)
        #expect(vm.hasActiveFilters == false)
    }
}

// MARK: - Transcript Parsing Tests

@Suite("TranscriptService HTML parsing")
struct TranscriptHTMLParsingTests {
    /// The exact shape Captivate.fm serves for a `text/html` transcript.
    private let html = """
    <cite>Speaker A</cite>
    <time>00:00:00</time>
    <p>Denne episoden passer for niva B1.</p>
    <cite>Speaker B</cite>
    <time>00:01:25</time>
    <p>Litt om Norges historie.</p>
    <cite>Speaker A</cite>
    <time>00:07:24</time>
    <p>Takk for naa.</p>
    """

    @Test func parsesCuesWithoutMarkup() throws {
        let transcript = try #require(
            TranscriptService.makeTranscript(
                from: Data(html.utf8),
                contentType: "text/html; charset=utf-8",
                url: "https://example.com/index.html"
            )
        )
        #expect(transcript.segments.count == 3)
        // The reported bug: tags rendered verbatim in the panel.
        #expect(transcript.segments.allSatisfy { !$0.text.contains("<") })
        #expect(transcript.segments[0].text == "Denne episoden passer for niva B1.")
    }

    @Test func readsTimestampsAndSpeakers() throws {
        let transcript = try #require(
            TranscriptService.makeTranscript(
                from: Data(html.utf8),
                contentType: "text/html",
                url: "https://example.com/index.html"
            )
        )
        #expect(transcript.segments[1].startTime == 85)
        #expect(transcript.segments[2].startTime == 444)
        #expect(transcript.segments[1].speaker == "Speaker B")
    }

    /// Every cue needs an end after its start, or lookup can never select it.
    @Test func fillsEndTimesFromNextCue() throws {
        let transcript = try #require(
            TranscriptService.makeTranscript(
                from: Data(html.utf8),
                contentType: "text/html",
                url: "https://example.com/index.html"
            )
        )
        #expect(transcript.segments[0].endTime == 85)
        #expect(transcript.segments.allSatisfy { $0.endTime > $0.startTime })

        let current = TranscriptService.getCurrentSegment(transcript, at: 90)
        #expect(current?.text == "Litt om Norges historie.")
    }

    /// HTML with paragraphs but no timings is kept and flagged unsynced, so
    /// the panel can show it as reading text without offering tap-to-seek or
    /// highlighting that it cannot honour.
    @Test func marksHTMLWithoutTimestampsAsUnsynced() throws {
        let page = "<p>Bare en vanlig side.</p><p>Ingen tidsstempler her.</p>"
        let transcript = try #require(
            TranscriptService.makeTranscript(
                from: Data(page.utf8),
                contentType: "text/html",
                url: "https://example.com/page.html"
            )
        )
        #expect(transcript.isSynced == false)
        #expect(transcript.segments.count == 2)
    }
}

// MARK: - Playback position saving

/// Minimal AudioPlaying stand-in: the position save path only reads episode,
/// time and duration, and never drives real playback.
@MainActor
final class StubAudioPlayer: AudioPlaying {
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var isLoading = false
    var hasError = false
    var playbackSpeed: Float = 1.0
    var currentEpisode: Episode?
    var currentPodcastTitle: String?
    var currentPodcastImage: String?
    var onRemotePlay: (() -> Void)?
    var pausedAt: Date?

    func play(episode: Episode, podcastTitle: String?, podcastImage: String?) {}
    func togglePlayPause() {}
    func pause() {}
    private(set) var seekedTo: TimeInterval?
    func seek(to time: TimeInterval) { seekedTo = time }
    func skipBackward() {}
    func skipForward() {}
    func setSpeed(_ speed: Float) {}
    func setVolume(_ volume: Float) {}
    func stop() {}
}

@Suite("Playback position saving")
@MainActor
struct PlaybackPositionSaveTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([QueueItem.self, Subscription.self, PlaybackPosition.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    private func makeEpisode() -> Episode {
        Episode(
            id: "ep-1",
            podcastId: "pod-1",
            title: "Test",
            description: "",
            audioUrl: "https://example.com/ep.mp3",
            duration: 1800,
            publishedAt: "2025-01-01T12:00:00Z",
            imageUrl: nil,
            transcriptUrl: nil,
            chaptersUrl: nil,
            season: nil,
            episode: nil,
            episodeType: nil,
            soundbites: nil
        )
    }

    private func storedPosition(in context: ModelContext) throws -> PlaybackPosition {
        let all = try context.fetch(FetchDescriptor<PlaybackPosition>())
        return try #require(all.first)
    }

    /// The save timer keeps running while playback is paused. Rewriting the row
    /// on every tick refreshed `updatedAt`, which is what smart resume measures
    /// the pause from — so a long pause looked seconds old and never rewound.
    @Test func pausedPlaybackDoesNotRefreshTheTimestamp() throws {
        let context = try makeContext()
        let audio = StubAudioPlayer()
        let vm = AudioPlayerViewModel(audioService: audio)
        vm.setup(context)

        audio.currentEpisode = makeEpisode()
        audio.duration = 1800
        audio.currentTime = 600
        vm.savePosition()

        let firstSave = try storedPosition(in: context).updatedAt

        // Paused: the timer fires again with the position standing still.
        vm.savePosition()

        #expect(try storedPosition(in: context).updatedAt == firstSave)
    }

    @Test func advancingPlaybackRefreshesTheTimestamp() throws {
        let context = try makeContext()
        let audio = StubAudioPlayer()
        let vm = AudioPlayerViewModel(audioService: audio)
        vm.setup(context)

        audio.currentEpisode = makeEpisode()
        audio.duration = 1800
        audio.currentTime = 600
        vm.savePosition()

        let firstSave = try storedPosition(in: context).updatedAt

        audio.currentTime = 605
        vm.savePosition()

        let stored = try storedPosition(in: context)
        #expect(stored.position == 605)
        #expect(stored.updatedAt > firstSave)
    }

    /// Reaching the end still has to be written even though the position has
    /// stopped moving, or the episode never counts as finished.
    @Test func completionIsStillWrittenWhenPositionStops() throws {
        let context = try makeContext()
        let audio = StubAudioPlayer()
        let vm = AudioPlayerViewModel(audioService: audio)
        vm.setup(context)

        audio.currentEpisode = makeEpisode()
        audio.duration = 1000
        audio.currentTime = 500
        vm.savePosition()
        #expect(try storedPosition(in: context).completed == false)

        audio.currentTime = 990
        vm.savePosition()

        #expect(try storedPosition(in: context).completed)
    }
}

@Suite("Smart resume")
@MainActor
struct SmartResumeTests {

    private let threshold = AppConstants.smartResumeThreshold
    private let rewind = AppConstants.smartResumeRewind

    private func makeContext() throws -> ModelContext {
        let schema = Schema([QueueItem.self, Subscription.self, PlaybackPosition.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    private func makeEpisode() -> Episode {
        Episode(
            id: "ep-1",
            podcastId: "pod-1",
            title: "Test",
            description: "",
            audioUrl: "https://example.com/ep.mp3",
            duration: 1800,
            publishedAt: "2025-01-01T12:00:00Z",
            imageUrl: nil,
            transcriptUrl: nil,
            chaptersUrl: nil,
            season: nil,
            episode: nil,
            episodeType: nil,
            soundbites: nil
        )
    }

    @Test func shortPauseResumesExactlyWhereItStopped() {
        let justNow = Date().addingTimeInterval(-(threshold - 60))
        #expect(AudioPlayerViewModel.smartResumePosition(600, pausedSince: justNow) == 600)
    }

    @Test func longPauseRewinds() {
        let longAgo = Date().addingTimeInterval(-(threshold + 60))
        #expect(AudioPlayerViewModel.smartResumePosition(600, pausedSince: longAgo) == 600 - rewind)
    }

    /// Rewinding past the opening seconds must land on the start, not a
    /// negative time the player cannot seek to.
    @Test func rewindNeverGoesBeforeTheStart() {
        let longAgo = Date().addingTimeInterval(-(threshold + 60))
        #expect(AudioPlayerViewModel.smartResumePosition(4, pausedSince: longAgo) == 0)
    }

    /// Remote play (lock screen, headphones) can restart an episode from the
    /// top; the position is restored, and after a long pause it earns the same
    /// rewind as every other resume path.
    @Test func remotePlayRestoreRewindsAfterALongPause() throws {
        let context = try makeContext()
        let audio = StubAudioPlayer()
        let vm = AudioPlayerViewModel(audioService: audio)
        vm.setup(context)

        context.insert(PlaybackPosition(
            episodeId: "ep-1",
            position: 600,
            duration: 1800,
            updatedAt: Date().addingTimeInterval(-(threshold + 60)),
            completed: false
        ))
        try context.save()

        audio.currentEpisode = makeEpisode()
        audio.duration = 1800
        audio.currentTime = 0

        audio.onRemotePlay?()

        #expect(audio.seekedTo == 600 - rewind)
    }

    @Test func remotePlayRestoreKeepsThePositionAfterAShortPause() throws {
        let context = try makeContext()
        let audio = StubAudioPlayer()
        let vm = AudioPlayerViewModel(audioService: audio)
        vm.setup(context)

        context.insert(PlaybackPosition(
            episodeId: "ep-1",
            position: 600,
            duration: 1800,
            updatedAt: Date().addingTimeInterval(-(threshold - 60)),
            completed: false
        ))
        try context.save()

        audio.currentEpisode = makeEpisode()
        audio.duration = 1800
        audio.currentTime = 0

        audio.onRemotePlay?()

        #expect(audio.seekedTo == 600)
    }
}

@Suite("TranscriptService regressions")
struct TranscriptRegressionTests {

    /// A speaker turn spanning several paragraphs used to keep the timestamp
    /// on the first paragraph only. The rest fell to 0:00 and then sorted to
    /// the top, so the transcript read out of order and tapping those lines
    /// seeked to the start of the episode.
    @Test func multiParagraphTurnKeepsItsTimestamp() throws {
        let html = """
        <cite>Pia</cite><time>00:01:00</time>
        <p>Foerste setning.</p>
        <p>Andre setning.</p>
        <cite>Julie</cite><time>00:02:00</time>
        <p>Svar.</p>
        """
        let transcript = try #require(
            TranscriptService.makeTranscript(
                from: Data(html.utf8),
                contentType: "text/html",
                url: "https://example.com/t.html"
            )
        )

        #expect(transcript.isSynced)
        #expect(transcript.segments.map(\.text) == ["Foerste setning.", "Andre setning.", "Svar."])
        #expect(transcript.segments.map(\.startTime) == [60, 60, 120])
    }

    /// Publishers put ordinary `<time>` elements in the page chrome. Reading a
    /// year as a seconds count marked the transcript synced with timings that
    /// were pure noise, instead of falling back to plain reading order.
    @Test func bareNumberIsNotATimestamp() throws {
        let html = "<time>2024</time><p>Publisert i fjor.</p><p>Selve samtalen.</p>"
        let transcript = try #require(
            TranscriptService.makeTranscript(
                from: Data(html.utf8),
                contentType: "text/html",
                url: "https://example.com/t.html"
            )
        )

        #expect(transcript.isSynced == false)
        #expect(transcript.segments.allSatisfy { $0.startTime == 0 })
    }

    @Test func clockNeedsAColon() {
        #expect(TranscriptService.parseClock("2024") == nil)
        #expect(TranscriptService.parseClock("01:30") == 90)
        #expect(TranscriptService.parseClock("01:00:00") == 3600)
    }

    /// Cues sharing a timestamp kept a zero-length window, so they could never
    /// be highlighted or scrolled to no matter where playback stood.
    @Test func cuesSharingAStartStillGetAWindow() {
        let segments = [
            TranscriptSegment(startTime: 10, endTime: 10, text: "Foerste", speaker: nil),
            TranscriptSegment(startTime: 10, endTime: 10, text: "Andre", speaker: nil)
        ]

        let normalized = TranscriptService.normalize(segments)

        #expect(normalized.allSatisfy { $0.endTime > $0.startTime })
    }

    /// `JSONSegment` has every field optional, so any JSON array of objects
    /// decoded successfully. Accepting that empty result stopped the VTT, SRT
    /// and HTML parsers from ever being tried.
    @Test func unknownJSONShapeFallsThroughToTheRealFormat() throws {
        let body = """
        [{"s": 0, "e": 2, "t": "ukjent form"}]
        """
        #expect(
            TranscriptService.makeTranscript(
                from: Data(body.utf8),
                contentType: "application/json",
                url: "https://example.com/t.json"
            ) == nil
        )

        let vtt = """
        WEBVTT

        00:00:01.000 --> 00:00:04.000
        Dette er ekte.
        """
        let transcript = try #require(
            TranscriptService.makeTranscript(
                from: Data(vtt.utf8),
                contentType: "application/json",
                url: "https://example.com/mislabelled.json"
            )
        )
        #expect(transcript.segments.first?.text == "Dette er ekte.")
    }

    /// `transcriptRank` still prefers text/plain over an unknown type, so one
    /// can be the best transcript on offer. Every other parser needs evidence
    /// of its own format, so these were selected and then reported missing.
    @Test func plainTextTranscriptIsReadable() throws {
        let body = Array(repeating: "Dette er en helt vanlig setning fra samtalen.", count: 20)
            .joined(separator: "\n\n")
        let transcript = try #require(
            TranscriptService.makeTranscript(
                from: Data(body.utf8),
                contentType: "text/plain",
                url: "https://example.com/t.txt"
            )
        )

        #expect(transcript.isSynced == false)
        #expect(transcript.segments.count == 20)
    }
}

@Suite("TranscriptService format fallbacks")
struct TranscriptFallbackTests {
    /// The regression that produced raw markup on screen: an unrecognised file
    /// fell through to the VTT parser, which accepted every line as one cue.
    @Test func doesNotSwallowNonTranscriptText() {
        let noise = "404 Not Found\nThe requested URL was not found on this server."
        let result = TranscriptService.makeTranscript(
            from: Data(noise.utf8),
            contentType: "text/plain",
            url: "https://example.com/missing.txt"
        )
        #expect(result == nil)
    }

    @Test func parsesVTT() throws {
        let vtt = """
        WEBVTT

        1
        00:00:01.000 --> 00:00:04.000
        <v Kari>God morgen, alle sammen.

        2
        00:00:04.000 --> 00:00:08.000
        I dag skal vi snakke om vaeret.
        """
        let transcript = try #require(
            TranscriptService.makeTranscript(
                from: Data(vtt.utf8),
                contentType: "text/vtt",
                url: "https://example.com/t.vtt"
            )
        )
        #expect(transcript.segments.count == 2)
        #expect(transcript.segments[0].speaker == "Kari")
        // The voice span must not reach the screen as text.
        #expect(transcript.segments[0].text == "God morgen, alle sammen.")
        #expect(transcript.segments[1].startTime == 4)
    }

    @Test func parsesSRT() throws {
        let srt = """
        1
        00:00:02,000 --> 00:00:05,500
        Velkommen til podkasten.

        2
        00:00:05,500 --> 00:00:09,000
        Vi starter med nyhetene.
        """
        let transcript = try #require(
            TranscriptService.makeTranscript(
                from: Data(srt.utf8),
                contentType: "application/srt",
                url: "https://example.com/t.srt"
            )
        )
        #expect(transcript.segments.count == 2)
        #expect(transcript.segments[0].startTime == 2)
        #expect(transcript.segments[1].text == "Vi starter med nyhetene.")
    }

    /// Norwegian transcripts are regularly served as latin-1 without saying so.
    /// Decoding as UTF-8 alone yields nil, which surfaced as "no transcript".
    @Test func decodesLatin1WhenNotUTF8() throws {
        let srt = """
        1
        00:00:01,000 --> 00:00:04,000
        Været på Vestlandet i dag.
        """
        let latin1 = try #require(srt.data(using: .isoLatin1))
        #expect(String(data: latin1, encoding: .utf8) == nil)

        let transcript = try #require(
            TranscriptService.makeTranscript(
                from: latin1,
                contentType: "application/srt",
                url: "https://example.com/t.srt"
            )
        )
        #expect(transcript.segments[0].text.contains("Været"))
    }
}

@Suite("TranscriptService word-level merging")
struct TranscriptMergingTests {
    /// Captivate's JSON transcripts carry one segment per spoken word.
    /// Rendered as-is that is hundreds of one-word rows in the panel.
    private func wordSegments() -> [TranscriptSegment] {
        let words = "Denne episoden handler om Norges historie og hvorfor vi feirer syttende mai hvert eneste aar."
            .split(separator: " ")
        return words.enumerated().map { index, word in
            TranscriptSegment(
                startTime: Double(index) * 0.4,
                endTime: Double(index) * 0.4 + 0.35,
                text: String(word)
            )
        }
    }

    @Test func detectsWordLevelInput() {
        #expect(TranscriptService.isWordLevel(wordSegments()))
    }

    @Test func mergesIntoReadableCues() {
        let merged = TranscriptService.normalize(wordSegments())
        #expect(merged.count < 5)
        #expect(merged[0].text.contains(" "))
        #expect(merged[0].startTime == 0)
    }

    /// Publisher-authored cues carry deliberate boundaries and seek points.
    @Test func leavesSentenceLevelCuesAlone() {
        let sentences = (0..<12).map { index in
            TranscriptSegment(
                startTime: Double(index) * 5,
                endTime: Double(index) * 5 + 5,
                text: "Dette er setning nummer \(index) i transkripsjonen."
            )
        }
        #expect(TranscriptService.isWordLevel(sentences) == false)
        #expect(TranscriptService.normalize(sentences).count == 12)
    }

    @Test func splitsOnSilenceGaps() {
        var segments = wordSegments()
        // A long pause mid-transcript must end the cue, not be glued over.
        for index in 8..<segments.count {
            segments[index].startTime += 60
            segments[index].endTime += 60
        }
        let merged = TranscriptService.normalize(segments)
        #expect(merged.count >= 2)
        #expect(merged.contains { $0.startTime >= 60 })
    }

    @Test func dropsEmptySegments() {
        let segments = [
            TranscriptSegment(startTime: 0, endTime: 2, text: "Hei"),
            TranscriptSegment(startTime: 2, endTime: 4, text: "   "),
            TranscriptSegment(startTime: 4, endTime: 6, text: "Hade"),
        ]
        #expect(TranscriptService.normalize(segments).count == 2)
    }
}

// MARK: - Chapter Parsing Tests

@Suite("ChapterService parsing")
struct ChapterParsingTests {
    @Test func parsesSpecShape() throws {
        let json = """
        {"version":"1.2.0","chapters":[
          {"startTime":0,"endTime":17.1},
          {"startTime":17.1,"endTime":153.2,"title":"Modalverb"},
          {"startTime":153.2,"title":"Skal"}
        ]}
        """
        let chapters = try #require(ChapterService.makeChapters(from: Data(json.utf8)))
        #expect(chapters.count == 3)
        // A chapter with no title still needs a label in the list.
        #expect(chapters[0].title == "Kapittel")
        #expect(chapters[1].title == "Modalverb")
    }

    /// Some generators emit a bare array instead of the wrapper object.
    @Test func parsesTopLevelArray() throws {
        let json = """
        [{"startTime":0,"title":"Intro"},{"startTime":90,"title":"Tema"}]
        """
        let chapters = try #require(ChapterService.makeChapters(from: Data(json.utf8)))
        #expect(chapters.count == 2)
        #expect(chapters[1].startTime == 90)
    }

    /// A strict Double decode threw on these and took the whole list with it,
    /// surfacing as "could not load the chapters".
    @Test func acceptsStringTimes() throws {
        let json = """
        {"chapters":[{"startTime":"0","title":"Intro"},{"startTime":"120.5","title":"Tema"}]}
        """
        let chapters = try #require(ChapterService.makeChapters(from: Data(json.utf8)))
        #expect(chapters.count == 2)
        #expect(chapters[1].startTime == 120.5)
    }

    /// `toc: false` marks artwork or link changes the publisher does not want
    /// listed as segments.
    @Test func hidesChaptersExcludedFromTableOfContents() throws {
        let json = """
        {"chapters":[
          {"startTime":0,"title":"Intro"},
          {"startTime":30,"title":"Bilde","toc":false},
          {"startTime":60,"title":"Tema","toc":true}
        ]}
        """
        let chapters = try #require(ChapterService.makeChapters(from: Data(json.utf8)))
        #expect(chapters.map(\.title) == ["Intro", "Tema"])
    }

    @Test func sortsAndDropsEntriesWithoutStartTime() throws {
        let json = """
        {"chapters":[{"startTime":300,"title":"Sist"},{"title":"Ugyldig"},{"startTime":10,"title":"Forst"}]}
        """
        let chapters = try #require(ChapterService.makeChapters(from: Data(json.utf8)))
        #expect(chapters.map(\.title) == ["Forst", "Sist"])
    }

    @Test func rejectsNonChapterPayload() {
        #expect(ChapterService.makeChapters(from: Data("not json at all".utf8)) == nil)
    }
}

// MARK: - Transcript Source Selection Tests

@Suite("PodcastTransform.bestTranscriptUrl")
struct BestTranscriptUrlTests {
    private func episode(
        transcriptUrl: String?,
        transcripts: [PodcastIndexTranscript]?
    ) -> PodcastIndexEpisode {
        PodcastIndexEpisode(
            id: 1, title: "T", link: nil, description: nil, guid: nil,
            datePublished: nil, datePublishedPretty: nil, enclosureUrl: nil,
            enclosureType: nil, enclosureLength: nil, duration: nil, explicit: nil,
            episode: nil, episodeType: nil, season: nil, image: nil,
            feedItunesId: nil, feedImage: nil, feedId: 1, feedLanguage: nil,
            feedDead: nil, chaptersUrl: nil, transcriptUrl: transcriptUrl,
            transcripts: transcripts, soundbite: nil, soundbites: nil,
            feedTitle: nil, feedAuthor: nil
        )
    }

    /// The reported bug in one assertion: the legacy field pointed at the HTML
    /// rendering even though the publisher also shipped JSON.
    @Test func prefersJSONOverHTML() {
        let result = PodcastTransform.bestTranscriptUrl(episode(
            transcriptUrl: "https://example.com/index.html",
            transcripts: [
                PodcastIndexTranscript(url: "https://example.com/index.html", type: "text/html"),
                PodcastIndexTranscript(url: "https://example.com/t.json", type: "application/json"),
                PodcastIndexTranscript(url: "https://example.com/t.srt", type: "application/srt"),
            ]
        ))
        #expect(result == "https://example.com/t.json")
    }

    @Test func prefersTimedFormatsOverPlainText() {
        let result = PodcastTransform.bestTranscriptUrl(episode(
            transcriptUrl: nil,
            transcripts: [
                PodcastIndexTranscript(url: "https://example.com/t.txt", type: "text/plain"),
                PodcastIndexTranscript(url: "https://example.com/t.srt", type: "application/srt"),
            ]
        ))
        #expect(result == "https://example.com/t.srt")
    }

    /// A few publishers report an empty or wrong mime type on a usable file.
    @Test func fallsBackToFileExtension() {
        let result = PodcastTransform.bestTranscriptUrl(episode(
            transcriptUrl: nil,
            transcripts: [
                PodcastIndexTranscript(url: "https://example.com/a.html", type: nil),
                PodcastIndexTranscript(url: "https://example.com/b.vtt", type: nil),
            ]
        ))
        #expect(result == "https://example.com/b.vtt")
    }

    @Test func fallsBackToLegacyFieldWhenArrayMissing() {
        let result = PodcastTransform.bestTranscriptUrl(episode(
            transcriptUrl: "https://example.com/legacy.srt",
            transcripts: nil
        ))
        #expect(result == "https://example.com/legacy.srt")
    }

    @Test func returnsNilWhenNothingUsable() {
        #expect(PodcastTransform.bestTranscriptUrl(episode(transcriptUrl: "  ", transcripts: [])) == nil)
    }
}

@Suite("TranscriptService unsynced transcripts")
struct TranscriptUnsyncedTests {
    /// Real shape from a hand-written Captivate transcript: good prose,
    /// no timing at all. Discarding it loses the best content some episodes
    /// have; faking 0:00 on every line would break tap-to-seek.
    private let html = """
    <p>Transkripsjon:</p>
    <p></p>
    <p>Pia: Hei, og velkommen til Norskpodden!</p>
    <p></p>
    <p>I dag skal vi snakke om den muntlige norskproven.</p>
    <p></p>
    <p>Julie: Jeg er litt nervos, men det gaar greit.</p>
    """

    private func parse() -> Transcript? {
        TranscriptService.makeTranscript(
            from: Data(html.utf8),
            contentType: "text/html",
            url: "https://example.com/index.html"
        )
    }

    @Test func keepsUntimedTranscript() throws {
        let transcript = try #require(parse())
        #expect(transcript.isSynced == false)
        #expect(transcript.segments.count == 4)
    }

    @Test func dropsEmptyParagraphs() throws {
        let transcript = try #require(parse())
        #expect(transcript.segments.allSatisfy { !$0.text.isEmpty })
    }

    /// Every start time is 0 here, and `sorted` is not stable — ordering an
    /// unsynced transcript would scramble it into an unreadable sequence.
    @Test func preservesDocumentOrder() throws {
        let transcript = try #require(parse())
        #expect(transcript.segments[0].text == "Transkripsjon:")
        #expect(transcript.segments[1].text == "Pia: Hei, og velkommen til Norskpodden!")
        #expect(transcript.segments[3].text.hasPrefix("Julie:"))
    }

    @Test func timedHTMLStaysSynced() throws {
        let timed = """
        <time>00:00:10</time><p>Forste del.</p>
        <time>00:00:40</time><p>Andre del.</p>
        """
        let transcript = try #require(
            TranscriptService.makeTranscript(
                from: Data(timed.utf8),
                contentType: "text/html",
                url: "https://example.com/t.html"
            )
        )
        #expect(transcript.isSynced)
        #expect(transcript.segments[0].startTime == 10)
    }
}

// MARK: - Player Layout Tests

@Suite("AudioPlayerSheet.artworkSide")
@MainActor
struct PlayerArtworkSizeTests {
    // Safe-area heights, not screen heights: that is what GeometryReader
    // reports inside the player.
    private let pro = CGSize(width: 402, height: 781)
    private let proMax = CGSize(width: 440, height: 863)

    /// The artwork used to be a hard 280pt, which left the surplus height as
    /// dead air above the image and wasted width on both current devices.
    @Test func growsBeyondTheOldFixedSize() {
        #expect(AudioPlayerSheet.artworkSide(in: pro, hasFeatureRow: false) > 280)
        #expect(AudioPlayerSheet.artworkSide(in: proMax, hasFeatureRow: false) > 280)
    }

    /// On the Pro Max the content width is what limits it, so the artwork
    /// spans the full column.
    @Test func fillsTheContentWidthWhenHeightAllows() {
        // Expressed rather than hardcoded: the number is the content width,
        // and AppSpacing has moved before.
        #expect(
            AudioPlayerSheet.artworkSide(in: proMax, hasFeatureRow: false)
                == proMax.width - AppSpacing.lg * 2
        )
    }

    @Test func growsWithTheLargerDevice() {
        let small = AudioPlayerSheet.artworkSide(in: pro, hasFeatureRow: false)
        let large = AudioPlayerSheet.artworkSide(in: proMax, hasFeatureRow: false)
        #expect(large > small)
    }

    /// The chapter and transcript row has to be paid for out of the artwork,
    /// or it would be pushed off the bottom of the screen.
    @Test func yieldsHeightToTheFeatureRow() {
        for size in [pro, proMax] {
            #expect(
                AudioPlayerSheet.artworkSide(in: size, hasFeatureRow: true)
                    < AudioPlayerSheet.artworkSide(in: size, hasFeatureRow: false)
            )
        }
    }

    /// Everything must still fit inside the space the player was given.
    @Test func neverOverflowsTheAvailableHeight() {
        for size in [pro, proMax, CGSize(width: 402, height: 600)] {
            for hasFeatureRow in [true, false] {
                let side = AudioPlayerSheet.artworkSide(in: size, hasFeatureRow: hasFeatureRow)
                let total = side + AudioPlayerSheet.reservedContentHeight(hasFeatureRow: hasFeatureRow)
                #expect(total <= size.height || side == AppSize.artworkMedium)
            }
        }
    }

    @Test func neverCollapsesBelowTheFloor() {
        let tiny = CGSize(width: 320, height: 400)
        #expect(AudioPlayerSheet.artworkSide(in: tiny, hasFeatureRow: true) == AppSize.artworkMedium)
    }
}

// MARK: - Last played record

@Suite("LastPlayedInfo")
struct LastPlayedInfoTests {

    /// Exactly what 1.0.7 wrote into UserDefaults: no `transcriptUrl`, no
    /// `chaptersUrl`. Everyone upgrading has one of these on disk, and a
    /// decode failure would empty the "Fortsett"-card without a word.
    private let legacyJSON = Data("""
    {
      "episodeId": "ep-1",
      "podcastId": "pod-1",
      "title": "Gammel episode",
      "audioUrl": "https://example.com/ep.mp3",
      "duration": 1800,
      "imageUrl": "https://example.com/ep.jpg",
      "podcastTitle": "Podden",
      "podcastImage": "https://example.com/pod.jpg"
    }
    """.utf8)

    @Test func decodesRecordsWrittenBeforeTheNewFields() throws {
        let info = try JSONDecoder().decode(LastPlayedInfo.self, from: legacyJSON)
        #expect(info.episodeId == "ep-1")
        #expect(info.podcastTitle == "Podden")
        #expect(info.transcriptUrl == nil)
        #expect(info.chaptersUrl == nil)
    }

    /// The rebuilt episode is what "Fortsett" hands to the player, so the two
    /// new fields have to survive the trip — that was the bug they fixed.
    @Test func rebuiltEpisodeCarriesChaptersAndTranscript() throws {
        let info = LastPlayedInfo(
            episodeId: "ep-2",
            podcastId: "pod-1",
            title: "Ny episode",
            audioUrl: "https://example.com/ep2.mp3",
            duration: 900,
            imageUrl: nil,
            podcastTitle: "Podden",
            podcastImage: "https://example.com/pod.jpg",
            transcriptUrl: "https://example.com/ep2.json",
            chaptersUrl: "https://example.com/ep2-chapters.json"
        )

        let decoded = try JSONDecoder().decode(
            LastPlayedInfo.self,
            from: try JSONEncoder().encode(info)
        )
        let episode = decoded.toEpisode()
        #expect(episode.transcriptUrl == "https://example.com/ep2.json")
        #expect(episode.chaptersUrl == "https://example.com/ep2-chapters.json")
    }

    /// A legacy record has neither, and must not invent them.
    @Test func rebuiltLegacyEpisodeHasNeither() throws {
        let episode = try JSONDecoder().decode(LastPlayedInfo.self, from: legacyJSON).toEpisode()
        #expect(episode.transcriptUrl == nil)
        #expect(episode.chaptersUrl == nil)
        #expect(episode.audioUrl == "https://example.com/ep.mp3")
    }
}

// MARK: - Behold episoder i køen

@Suite("QueueViewModel keep-in-queue rule")
@MainActor
struct QueueKeepRuleTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([QueueItem.self, Subscription.self, PlaybackPosition.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    private func makeEpisode(_ id: String) -> Episode {
        Episode(
            id: id, podcastId: "pod-1", title: "Episode \(id)", description: "",
            audioUrl: "https://example.com/\(id).mp3", duration: 600,
            publishedAt: "2025-01-01T12:00:00Z", imageUrl: nil
        )
    }

    /// A throwaway suite, so flipping the setting never touches the defaults
    /// the simulator or another test is using.
    private func makeVM(in context: ModelContext, keepsEpisodes: Bool) -> (QueueViewModel, UserDefaults, String) {
        let suiteName = "queue-rule-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(keepsEpisodes, forKey: AppConstants.keepEpisodesInQueueKey)
        let vm = QueueViewModel(defaults: defaults)
        vm.setup(context)
        for id in ["a", "b", "c"] {
            vm.addToQueue(episode: makeEpisode(id), podcastTitle: "Podden", podcastImage: nil)
        }
        return (vm, defaults, suiteName)
    }

    @Test("playing a queue row removes it by default")
    func removesByDefault() throws {
        let context = try makeContext()
        let (vm, _, suite) = makeVM(in: context, keepsEpisodes: false)
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        vm.removeAfterPlay(vm.items[0])
        #expect(vm.items.map(\.episodeId) == ["b", "c"])
    }

    @Test("the setting keeps the row where it is")
    func keepsWhenAsked() throws {
        let context = try makeContext()
        let (vm, _, suite) = makeVM(in: context, keepsEpisodes: true)
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        vm.removeAfterPlay(vm.items[0])
        #expect(vm.items.count == 3)
    }

    /// Without the setting the finished episode is already gone, so the next
    /// one to play is simply the new head of the queue.
    @Test("auto-advance pops the head when episodes are consumed")
    func autoAdvancePops() throws {
        let context = try makeContext()
        let (vm, _, suite) = makeVM(in: context, keepsEpisodes: false)
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        let next = try #require(vm.nextAfterPlaying(episodeId: "a"))
        #expect(next.episode.id == "a")
        #expect(vm.items.count == 2)
    }

    /// With the setting on, the episode that just finished is still sitting in
    /// the queue. Popping would replay it forever — and remove it, which is the
    /// one thing the setting promises not to do.
    @Test("auto-advance steps past the finished episode when it stays")
    func autoAdvanceStepsPast() throws {
        let context = try makeContext()
        let (vm, _, suite) = makeVM(in: context, keepsEpisodes: true)
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        let next = try #require(vm.nextAfterPlaying(episodeId: "a"))
        #expect(next.episode.id == "b")
        #expect(vm.items.count == 3)
    }

    @Test("auto-advance stops at the end of a kept queue")
    func autoAdvanceStopsAtTheEnd() throws {
        let context = try makeContext()
        let (vm, _, suite) = makeVM(in: context, keepsEpisodes: true)
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        #expect(vm.nextAfterPlaying(episodeId: "c") == nil)
    }

    /// An episode started from the podcast page is not in the queue at all.
    /// Auto-advance should then start the queue from the top rather than stop.
    @Test("an episode played from elsewhere starts the queue")
    func startsQueueFromOutside() throws {
        let context = try makeContext()
        let (vm, _, suite) = makeVM(in: context, keepsEpisodes: true)
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        let next = try #require(vm.nextAfterPlaying(episodeId: "ukjent"))
        #expect(next.episode.id == "a")
    }
}

// MARK: - Playback position retention

@Suite("PlaybackProgressViewModel cleanup")
@MainActor
struct PlaybackProgressCleanupTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([QueueItem.self, Subscription.self, PlaybackPosition.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    private func daysAgo(_ days: Int) -> Date {
        Date().addingTimeInterval(TimeInterval(-days * 24 * 3600))
    }

    private func insert(_ context: ModelContext, id: String, completed: Bool, ageInDays: Int) {
        context.insert(
            PlaybackPosition(
                episodeId: id, position: 120, duration: 1800,
                updatedAt: daysAgo(ageInDays), completed: completed
            )
        )
    }

    private func storedIds(_ context: ModelContext) throws -> Set<String> {
        Set(try context.fetch(FetchDescriptor<PlaybackPosition>()).map(\.episodeId))
    }

    /// The purge runs on every launch and deletes listening history, which is
    /// the one thing in the app nobody can get back.
    @Test("a finished episode is kept for the full retention period")
    func keepsRecentlyCompleted() throws {
        let context = try makeContext()
        insert(context, id: "fresh", completed: true, ageInDays: AppConstants.completedPositionRetentionDays - 5)
        insert(context, id: "stale", completed: true, ageInDays: AppConstants.completedPositionRetentionDays + 5)

        PlaybackProgressViewModel().setup(context)

        #expect(try storedIds(context) == ["fresh"])
    }

    /// Unfinished episodes get the longer grace: someone may well pick a
    /// half-listened episode back up months later.
    @Test("an unfinished episode gets the longer grace period")
    func unfinishedOutlivesTheCompletedCutoff() throws {
        let context = try makeContext()
        insert(context, id: "unfinished", completed: false, ageInDays: AppConstants.completedPositionRetentionDays + 5)
        insert(context, id: "ancient", completed: false, ageInDays: AppConstants.incompletePositionRetentionDays + 5)

        PlaybackProgressViewModel().setup(context)

        #expect(try storedIds(context) == ["unfinished"])
    }

    @Test("an empty store survives the purge untouched")
    func emptyStoreIsFine() throws {
        let context = try makeContext()
        PlaybackProgressViewModel().setup(context)
        #expect(try storedIds(context).isEmpty)
    }

    /// "Fjern fra Fortsett å lytte" leans on this: it must take out the one
    /// episode and nothing else.
    @Test("clearProgress removes only the episode it was given")
    func clearProgressIsTargeted() throws {
        let context = try makeContext()
        insert(context, id: "keep", completed: false, ageInDays: 1)
        insert(context, id: "drop", completed: false, ageInDays: 1)

        let vm = PlaybackProgressViewModel()
        vm.setup(context)
        vm.clearProgress(for: "drop")

        #expect(try storedIds(context) == ["keep"])
        #expect(vm.getProgress(for: "drop") == nil)
    }
}

// MARK: - Delete everything

@Suite("DataTransferService.deleteAllUserDefaults")
struct DeleteUserDefaultsTests {

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "delete-defaults-\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }

    /// The list is the contract: a key that is not on it is a key "Slett alle
    /// data" quietly leaves behind, which is what happened to the queue
    /// setting when it was added.
    @Test("every key the app owns is gone afterwards")
    func clearsEveryKey() {
        let (defaults, suiteName) = makeDefaults()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        for key in AppConstants.userDataDefaultsKeys {
            defaults.set("noe", forKey: key)
        }

        DataTransferService.deleteAllUserDefaults(in: defaults)

        for key in AppConstants.userDataDefaultsKeys {
            #expect(defaults.object(forKey: key) == nil, "\(key) ble ikke slettet")
        }
    }

    @Test("keys the app does not own are left alone")
    func leavesForeignKeysAlone() {
        let (defaults, suiteName) = makeDefaults()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        defaults.set(true, forKey: "AppleLanguages-ish")
        DataTransferService.deleteAllUserDefaults(in: defaults)
        #expect(defaults.object(forKey: "AppleLanguages-ish") != nil)
    }

    /// Guards the list against a key silently dropping out of it.
    @Test("the list still names every settings key the app writes")
    func listIsComplete() {
        let keys = Set(AppConstants.userDataDefaultsKeys)
        #expect(keys.contains(AppConstants.lastPlayedInfoKey))
        #expect(keys.contains(AppConstants.showLastPlayedKey))
        #expect(keys.contains(AppConstants.showNewFromSubscriptionsKey))
        #expect(keys.contains(AppConstants.podcastSpeedPrefsKey))
        #expect(keys.contains(AppConstants.keepEpisodesInQueueKey))
        #expect(keys.count == AppConstants.userDataDefaultsKeys.count, "duplikater i lista")
    }
}

// MARK: - Chapter highlighting

@Suite("AudioPlayerViewModel.currentChapter")
@MainActor
struct CurrentChapterTests {

    private let chapters = [
        Chapter(startTime: 0, title: "Intro"),
        Chapter(startTime: 120, title: "Hoveddel"),
        Chapter(startTime: 600, title: "Avslutning")
    ]

    private func makeEpisode(chaptersUrl: String?) -> Episode {
        Episode(
            id: "ep-1", podcastId: "pod-1", title: "Test", description: "",
            audioUrl: "https://example.com/ep.mp3", duration: 1800,
            publishedAt: "2025-01-01T12:00:00Z", imageUrl: nil,
            transcriptUrl: nil, chaptersUrl: chaptersUrl
        )
    }

    /// It used to be a stored property refreshed from the position-save timer,
    /// so the highlight lagged up to `playbackSaveInterval` seconds behind —
    /// most visibly right after tapping a chapter to seek to it.
    @Test func followsTheClockWithoutATimerTick() {
        let audio = StubAudioPlayer()
        let vm = AudioPlayerViewModel(audioService: audio)
        vm.chapters = chapters

        audio.currentTime = 5
        #expect(vm.currentChapter?.title == "Intro")

        audio.currentTime = 599
        #expect(vm.currentChapter?.title == "Hoveddel")

        audio.currentTime = 600
        #expect(vm.currentChapter?.title == "Avslutning")
    }

    @Test func isNilWhenTheEpisodeHasNoChapters() {
        let audio = StubAudioPlayer()
        let vm = AudioPlayerViewModel(audioService: audio)
        audio.currentTime = 300
        #expect(vm.currentChapter == nil)
    }

    /// Loading an episode without chapters has to clear the previous one's,
    /// or the old list stays on screen under a new episode.
    @Test func loadingAnEpisodeWithoutChaptersClearsThePreviousOnes() {
        let audio = StubAudioPlayer()
        let vm = AudioPlayerViewModel(audioService: audio)
        vm.chapters = chapters
        vm.chaptersFailed = true

        vm.loadChapters(for: makeEpisode(chaptersUrl: nil))

        #expect(vm.chapters.isEmpty)
        #expect(vm.chaptersFailed == false)
        #expect(vm.currentChapter == nil)
    }
}

// MARK: - Episode row artwork

/// `@MainActor` for the same reason as the player layout suite: these are
/// statics on a SwiftUI `View`, and reaching them off the main actor takes the
/// test process down rather than failing an expectation.
@Suite("EpisodeCard.artworkURL")
@MainActor
struct EpisodeCardArtworkTests {

    private let episodeArt = "https://example.com/episode.jpg"
    private let podcastArt = "https://example.com/podcast.jpg"

    /// Home and the queue mix shows, and per-episode artwork made it hard to
    /// see which podcast a row belonged to.
    @Test func prefersThePodcastArtworkWhenAsked() {
        #expect(
            EpisodeCard.artworkURL(episodeImage: episodeArt, podcastImage: podcastArt, usePodcastArtwork: true)
                == podcastArt
        )
    }

    @Test func usesTheEpisodeArtworkOtherwise() {
        #expect(
            EpisodeCard.artworkURL(episodeImage: episodeArt, podcastImage: podcastArt, usePodcastArtwork: false)
                == episodeArt
        )
    }

    /// A row must never end up with an empty image just because it asked for
    /// the show's and the show has none.
    @Test func fallsBackToTheEpisodeWhenThePodcastHasNoArtwork() {
        #expect(
            EpisodeCard.artworkURL(episodeImage: episodeArt, podcastImage: "", usePodcastArtwork: true)
                == episodeArt
        )
    }

    @Test func fallsBackToThePodcastWhenTheEpisodeHasNone() {
        #expect(
            EpisodeCard.artworkURL(episodeImage: nil, podcastImage: podcastArt, usePodcastArtwork: false)
                == podcastArt
        )
        #expect(
            EpisodeCard.artworkURL(episodeImage: "", podcastImage: podcastArt, usePodcastArtwork: false)
                == podcastArt
        )
    }
}

// MARK: - Artwork downsampling

@Suite("CachedAsyncImage.downsample")
@MainActor
struct ArtworkDownsampleTests {

    /// `scale = 1` so `side` is pixels, not points: the downsampler works in
    /// pixels, and a renderer left at the device scale produced a 240px source
    /// for an "80pt" image — which made the first version of these assertions
    /// compare a point size against a pixel target.
    private func jpeg(side: CGFloat) throws -> Data {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side),
            format: format
        ).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        }
        return try #require(image.jpegData(compressionQuality: 0.9))
    }

    private func pixelSide(_ image: UIImage) throws -> Int {
        let cgImage = try #require(image.cgImage)
        return max(cgImage.width, cgImage.height)
    }

    /// Podcast covers arrive at around 1400x1400 and are shown at 56pt. The
    /// old path decoded the full bitmap and redrew it; this one decodes to the
    /// size actually needed, and - the part that matters for scrolling - does
    /// it off the main actor.
    @Test func capsTheLongestSideAtTheTarget() throws {
        let data = try jpeg(side: 1400)
        let image = try #require(CachedAsyncImage.downsample(data, to: 168))
        #expect(try pixelSide(image) <= 168)
    }

    /// Artwork smaller than the target must not be blown up - that would cost
    /// memory and look worse than the original.
    @Test func leavesSmallArtworkAlone() throws {
        let data = try jpeg(side: 80)
        let image = try #require(CachedAsyncImage.downsample(data, to: 168))
        #expect(try pixelSide(image) == 80)
    }

    /// A 200 that is not an image at all - an error page, say - has to come
    /// back as a failure so the row shows its placeholder.
    @Test func rejectsDataThatIsNotAnImage() {
        #expect(CachedAsyncImage.downsample(Data("<html>nope</html>".utf8), to: 168) == nil)
        #expect(CachedAsyncImage.downsample(Data(), to: 168) == nil)
    }
}
