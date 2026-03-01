import Foundation
import Testing
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
        let yesterday = iso8601BasicFormatter.string(from: Date().addingTimeInterval(-86400))
        #expect(formatRelativeDate(yesterday) == "I går")
    }

    @Test func daysAgo() {
        let threeDaysAgo = iso8601BasicFormatter.string(from: Date().addingTimeInterval(-3 * 86400))
        #expect(formatRelativeDate(threeDaysAgo) == "3 dager siden")
    }

    @Test func weeksAgo() {
        let tenDaysAgo = iso8601BasicFormatter.string(from: Date().addingTimeInterval(-10 * 86400))
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
