import Foundation

enum PodcastTransform {

    // MARK: - Cached Regex

    private static let linkRegex = try! NSRegularExpression(pattern: "<a[^>]*href=[\"']([^\"']+)[\"'][^>]*>([^<]*)</a>")
    private static let blockRegex = try! NSRegularExpression(pattern: "<(p|div|br|h[1-6]|li|tr)[^>]*>")
    private static let tagRegex = try! NSRegularExpression(pattern: "<[^>]*>")
    private static let spacesRegex = try! NSRegularExpression(pattern: "[ \\t]+")
    private static let newlinesRegex = try! NSRegularExpression(pattern: "\\n{3,}")
    private static let truncatedTagRegex = try! NSRegularExpression(pattern: "<[^>]*$")

    // MARK: - Feed Transform

    /// Norwegian placeholders for records without a title — every UI string is
    /// Norwegian, so "Untitled" was a defect, not a default. Exposed so other
    /// layers (OPML resolve) can recognize a placeholder and prefer their own
    /// source's title over it.
    static let untitledPodcast = "Uten tittel"
    static let untitledEpisode = "Episode uten tittel"

    static func transformFeed(_ feed: PodcastIndexFeed) -> Podcast {
        Podcast(
            id: String(feed.id),
            title: feed.title ?? untitledPodcast,
            author: feed.author ?? feed.ownerName ?? "Ukjent",
            description: htmlToText(feed.description ?? ""),
            imageUrl: feed.artwork ?? feed.image ?? "",
            feedUrl: feed.url ?? feed.originalUrl ?? "",
            // Dictionary order is randomized per launch; sorted keeps the same
            // three badges showing on every visit.
            categories: Array((feed.categories ?? [:]).values).sorted(),
            language: normalizeLanguage(feed.language ?? ""),
            episodeCount: feed.episodeCount ?? 0,
            lastUpdated: safeTimestampToISO(feed.lastUpdateTime),
            explicit: feed.explicit ?? false
        )
    }

    static func transformFeeds(_ feeds: [PodcastIndexFeed]) -> [Podcast] {
        feeds
            .filter { ($0.dead ?? 0) == 0 }
            .map(transformFeed)
    }

    // MARK: - Episode Transform

    static func transformEpisode(_ episode: PodcastIndexEpisode) -> Episode {
        // feedId is the Podcast Index numeric feed ID. It is nil for some search results
        // (e.g. /search/byperson). Use feedTitle or feedAuthor as last-resort context.
        // Never use "" — an empty podcastId silently breaks navigation and cross-referencing.
        let podcastId: String
        if let feedId = episode.feedId {
            podcastId = String(feedId)
        } else if let feedTitle = episode.feedTitle {
            podcastId = "unknown:\(feedTitle.lowercased().replacingOccurrences(of: " ", with: "-"))"
        } else {
            podcastId = "unknown:\(episode.id)"
        }

        return Episode(
            id: String(episode.id),
            podcastId: podcastId,
            title: episode.title ?? untitledEpisode,
            description: htmlToText(episode.description ?? ""),
            audioUrl: episode.enclosureUrl ?? "",
            duration: TimeInterval(episode.duration ?? 0),
            publishedAt: safeTimestampToISO(episode.datePublished),
            imageUrl: episode.image ?? episode.feedImage,
            transcriptUrl: bestTranscriptUrl(episode),
            chaptersUrl: episode.chaptersUrl,
            season: episode.season.flatMap { $0 > 0 ? $0 : nil },
            episode: episode.episode.flatMap { $0 > 0 ? $0 : nil },
            episodeType: normalizeEpisodeType(episode.episodeType),
            soundbites: transformSoundbites(episode.soundbite, episode.soundbites)
        )
    }

    static func transformEpisodes(_ episodes: [PodcastIndexEpisode]) -> [Episode] {
        episodes.map(transformEpisode)
    }

    // MARK: - Off the main actor

    /// A full search response is 200-400 feeds, and stripping HTML from their
    /// descriptions is tens of milliseconds of regex work. Run on the main
    /// actor it lands on exactly the frame that shows the results, which is
    /// where it is most visible. The inputs and outputs are all `Sendable`
    /// value types, so moving it costs nothing but the hop.
    static func transformFeeds(offMain feeds: [PodcastIndexFeed]) async -> [Podcast] {
        await Task.detached(priority: .userInitiated) { transformFeeds(feeds) }.value
    }

    static func transformEpisodes(offMain episodes: [PodcastIndexEpisode]) async -> [Episode] {
        await Task.detached(priority: .userInitiated) { transformEpisodes(episodes) }.value
    }

    // MARK: - Transcript selection

    /// Lower sorts first. JSON carries per-word times and speakers; VTT and SRT
    /// carry timed cues; HTML only has a coarse timestamp per paragraph; plain
    /// text has no timing at all and cannot drive a synced transcript.
    private static func transcriptRank(_ type: String?) -> Int {
        switch type?.lowercased() {
        case "application/json": return 0
        case "text/vtt": return 1
        case "application/srt", "text/srt", "application/x-subrip": return 2
        case "text/html": return 3
        case "text/plain": return 4
        default: return 5
        }
    }

    /// Falls back to the file extension, because a few publishers report an
    /// empty or wrong mime type on an otherwise usable file.
    private static func transcriptRankByExtension(_ url: String) -> Int {
        let lower = url.lowercased()
        if lower.hasSuffix(".json") { return 0 }
        if lower.hasSuffix(".vtt") { return 1 }
        if lower.hasSuffix(".srt") { return 2 }
        if lower.hasSuffix(".html") || lower.hasSuffix(".htm") { return 3 }
        return 5
    }

    /// Podcast Index's API docs say the `transcripts` array should be used
    /// instead of the legacy `transcriptUrl` in most cases, and real feeds show
    /// why: where a publisher ships JSON, SRT and HTML of the same transcript,
    /// the legacy field can hand back the HTML one, which is markup rather than
    /// cues. Prefer the most machine-readable format on offer.
    static func bestTranscriptUrl(_ episode: PodcastIndexEpisode) -> String? {
        let candidates = (episode.transcripts ?? [])
            .compactMap { entry -> (url: String, rank: Int)? in
                guard let url = entry.url?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !url.isEmpty else { return nil }
                return (url, min(transcriptRank(entry.type), transcriptRankByExtension(url)))
            }

        if let best = candidates.min(by: { $0.rank < $1.rank }) {
            return best.url
        }

        let legacy = episode.transcriptUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
        return legacy?.isEmpty == false ? legacy : nil
    }

    // MARK: - Helpers

    private static func safeTimestampToISO(_ timestamp: Int?) -> String {
        guard let timestamp, timestamp > 0 else {
            // Return empty string for missing/zero timestamps — callers treat "" as "unknown"
            // Previously returned current date, making stale feeds appear freshly updated
            return ""
        }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        return iso8601BasicFormatter.string(from: date)
    }

    private static func normalizeLanguage(_ lang: String) -> String {
        guard !lang.isEmpty else { return "Unknown" }
        let langMap: [String: String] = [
            "no": "Norsk", "nb": "Norsk", "nn": "Nynorsk",
            "en": "English", "en-us": "English", "en-gb": "English",
            "sv": "Svenska", "da": "Dansk", "de": "Deutsch",
            "fr": "Français", "es": "Español", "fi": "Suomi", "is": "Íslenska",
        ]
        let lower = lang.lowercased()
        let normalized = lower.split(separator: "-").first.map(String.init) ?? lower
        return langMap[lower] ?? langMap[normalized] ?? lang.uppercased()
    }

    private static func normalizeEpisodeType(_ type: String?) -> EpisodeType? {
        guard let type else { return nil }
        switch type.lowercased() {
        case "trailer": return .trailer
        case "bonus": return .bonus
        case "full": return .full
        default: return nil
        }
    }

    private static func transformSoundbites(
        _ soundbite: PodcastIndexSoundbite?,
        _ soundbites: [PodcastIndexSoundbite]?
    ) -> [Soundbite]? {
        var result: [Soundbite] = []

        if let sb = soundbite, sb.startTime >= 0, sb.duration > 0 {
            result.append(Soundbite(startTime: sb.startTime, duration: sb.duration, title: sb.title ?? "Høydepunkt"))
        }

        for sb in soundbites ?? [] {
            guard sb.startTime >= 0, sb.duration > 0 else { continue }
            let isDuplicate = result.contains { $0.startTime == sb.startTime && $0.duration == sb.duration }
            if !isDuplicate {
                result.append(Soundbite(startTime: sb.startTime, duration: sb.duration, title: sb.title ?? "Høydepunkt"))
            }
        }

        return result.isEmpty ? nil : result
    }

    // MARK: - HTML to Text

    static func htmlToText(_ html: String) -> String {
        let range = NSRange(html.startIndex..., in: html)
        // Convert links to markers
        var text = linkRegex.stringByReplacingMatches(in: html, range: range, withTemplate: "$2")
        var nsRange = NSRange(text.startIndex..., in: text)
        // Newlines before block elements
        text = blockRegex.stringByReplacingMatches(in: text, range: nsRange, withTemplate: "\n")
        nsRange = NSRange(text.startIndex..., in: text)
        // Remove remaining HTML
        text = tagRegex.stringByReplacingMatches(in: text, range: nsRange, withTemplate: "")
        nsRange = NSRange(text.startIndex..., in: text)
        // Remove truncated tags (API may cut off mid-tag)
        text = truncatedTagRegex.stringByReplacingMatches(in: text, range: nsRange, withTemplate: "")
        // Decode entities
        text = decodeHTMLEntities(text)
        nsRange = NSRange(text.startIndex..., in: text)
        // Clean whitespace
        text = spacesRegex.stringByReplacingMatches(in: text, range: nsRange, withTemplate: " ")
        nsRange = NSRange(text.startIndex..., in: text)
        text = newlinesRegex.stringByReplacingMatches(in: text, range: nsRange, withTemplate: "\n\n")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let entityRegex = try! NSRegularExpression(pattern: "&#(x[0-9a-fA-F]+|\\d+);")

    private static let namedEntities: [String: String] = [
        "&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">",
        "&quot;": "\"", "&#39;": "'", "&apos;": "'",
        "&mdash;": "\u{2014}", "&ndash;": "\u{2013}", "&hellip;": "\u{2026}",
        "&lsquo;": "\u{2018}", "&rsquo;": "\u{2019}",
        "&ldquo;": "\u{201C}", "&rdquo;": "\u{201D}",
        "&bull;": "\u{2022}", "&middot;": "\u{00B7}",
        "&copy;": "\u{00A9}", "&reg;": "\u{00AE}", "&trade;": "\u{2122}",
        "&eacute;": "\u{00E9}", "&egrave;": "\u{00E8}",
        "&aring;": "\u{00E5}", "&oslash;": "\u{00F8}", "&aelig;": "\u{00E6}",
        "&Aring;": "\u{00C5}", "&Oslash;": "\u{00D8}", "&AElig;": "\u{00C6}",
        "&uuml;": "\u{00FC}", "&ouml;": "\u{00F6}", "&auml;": "\u{00E4}",
    ]

    private static func decodeHTMLEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = text
        for (entity, replacement) in namedEntities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        // Decode numeric entities (&#123; and &#xAB;)
        let nsRange = NSRange(result.startIndex..., in: result)
        let matches = entityRegex.matches(in: result, range: nsRange).reversed()
        for match in matches {
            guard let codeRange = Range(match.range(at: 1), in: result) else { continue }
            let codeStr = String(result[codeRange])
            let codePoint: UInt32?
            if codeStr.hasPrefix("x") {
                codePoint = UInt32(codeStr.dropFirst(), radix: 16)
            } else {
                codePoint = UInt32(codeStr)
            }
            if let cp = codePoint, let scalar = Unicode.Scalar(cp) {
                let fullRange = Range(match.range, in: result)!
                result.replaceSubrange(fullRange, with: String(scalar))
            }
        }
        return result
    }
}
