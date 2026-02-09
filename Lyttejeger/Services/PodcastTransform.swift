import Foundation

enum PodcastTransform {

    // MARK: - Cached Formatters & Regex

    private nonisolated(unsafe) static let isoFormatter = ISO8601DateFormatter()
    private static let linkRegex = try! NSRegularExpression(pattern: "<a[^>]*href=[\"']([^\"']+)[\"'][^>]*>([^<]*)</a>")
    private static let blockRegex = try! NSRegularExpression(pattern: "<(p|div|br|h[1-6]|li|tr)[^>]*>")
    private static let tagRegex = try! NSRegularExpression(pattern: "<[^>]*>")
    private static let spacesRegex = try! NSRegularExpression(pattern: "[ \\t]+")
    private static let newlinesRegex = try! NSRegularExpression(pattern: "\\n{3,}")

    // MARK: - Feed Transform

    static func transformFeed(_ feed: PodcastIndexFeed) -> Podcast {
        Podcast(
            id: String(feed.id),
            guid: feed.podcastGuid,
            title: feed.title ?? "Untitled",
            author: feed.author ?? feed.ownerName ?? "Ukjent",
            description: htmlToText(feed.description ?? ""),
            imageUrl: feed.artwork ?? feed.image ?? "",
            feedUrl: feed.url ?? feed.originalUrl ?? "",
            websiteUrl: feed.link,
            categories: Array((feed.categories ?? [:]).values),
            language: normalizeLanguage(feed.language ?? ""),
            episodeCount: feed.episodeCount ?? 0,
            lastUpdated: safeTimestampToISO(feed.lastUpdateTime),
            rating: calculateRating(feed),
            explicit: feed.explicit ?? false,
            itunesId: feed.itunesId
        )
    }

    static func transformFeeds(_ feeds: [PodcastIndexFeed]) -> [Podcast] {
        feeds
            .filter { ($0.dead ?? 0) == 0 }
            .map(transformFeed)
    }

    // MARK: - Episode Transform

    static func transformEpisode(_ episode: PodcastIndexEpisode) -> Episode {
        Episode(
            id: String(episode.id),
            podcastId: String(episode.feedId ?? 0),
            title: episode.title ?? "Untitled Episode",
            description: htmlToText(episode.description ?? ""),
            audioUrl: episode.enclosureUrl ?? "",
            duration: TimeInterval(episode.duration ?? 0),
            publishedAt: safeTimestampToISO(episode.datePublished),
            imageUrl: episode.image ?? episode.feedImage,
            transcriptUrl: episode.transcriptUrl,
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

    // MARK: - Helpers

    private static func safeTimestampToISO(_ timestamp: Int?) -> String {
        guard let timestamp, timestamp > 0 else {
            return isoFormatter.string(from: Date())
        }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        return isoFormatter.string(from: date)
    }

    private static func normalizeLanguage(_ lang: String) -> String {
        guard !lang.isEmpty else { return "Unknown" }
        let langMap: [String: String] = [
            "no": "Norsk", "nb": "Norsk", "nn": "Nynorsk",
            "en": "English", "en-us": "English", "en-gb": "English",
            "sv": "Svenska", "da": "Dansk", "de": "Deutsch",
            "fr": "Français", "es": "Español", "fi": "Suomi", "is": "Íslenska",
        ]
        let normalized = lang.lowercased().split(separator: "-").first.map(String.init) ?? lang.lowercased()
        return langMap[lang.lowercased()] ?? langMap[normalized] ?? lang.uppercased()
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

    private static func calculateRating(_ feed: PodcastIndexFeed) -> Double {
        var score = 3.0

        let episodeCount = feed.episodeCount ?? 0
        if episodeCount > 100 { score += 0.5 }
        else if episodeCount > 50 { score += 0.3 }
        else if episodeCount > 20 { score += 0.1 }

        if let lastUpdate = feed.lastUpdateTime {
            let daysSinceUpdate = (Date().timeIntervalSince1970 - Double(lastUpdate)) / 86400
            if daysSinceUpdate < 7 { score += 0.5 }
            else if daysSinceUpdate < 30 { score += 0.3 }
            else if daysSinceUpdate < 90 { score += 0.1 }
        }

        if (feed.crawlErrors ?? 0) > 0 || (feed.parseErrors ?? 0) > 0 {
            score -= 0.3
        }

        return min(5, max(1, (score * 10).rounded() / 10))
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
