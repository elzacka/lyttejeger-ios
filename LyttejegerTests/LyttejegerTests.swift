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
