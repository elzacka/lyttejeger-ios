import Foundation
import os

// MARK: - Parsed feed

/// A podcast RSS feed after parsing: channel metadata plus its episodes.
struct PodcastFeedResult: Sendable {
    let podcastTitle: String
    let podcastDescription: String
    let podcastImageUrl: String
    let episodes: [Episode]
}

/// Lightweight RSS 2.0 parser for podcast feeds.
///
/// Used for NRK feeds and for any feed imported from OPML that Podcast Index
/// does not know. Nothing here is NRK-specific.
final class PodcastRSSParser: NSObject, XMLParserDelegate {
    private let data: Data
    private let podcastId: String

    // Channel metadata
    private var channelTitle = ""
    private var channelDescription = ""
    private var channelImageUrl = ""

    // Current item being parsed
    private var episodes: [Episode] = []
    private var currentTitle = ""
    private var currentDescription = ""
    private var currentAudioUrl = ""
    private var currentDuration = ""
    private var currentPubDate = ""
    private var currentImageUrl = ""
    private var currentGuid = ""

    // Parser state
    private var inChannel = false
    private var inItem = false
    // Depth inside channel sub-containers (<image>, <textInput>, <podcast:liveItem>)
    // whose own <title>/<description> must not overwrite the channel's.
    private var channelSubElementDepth = 0
    private var currentElement = ""
    private var textBuffer = ""

    private static let pubDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return f
    }()

    // Real feeds also write named zones ("EST", "CEST") and minutes-only times,
    // which the primary RFC 2822 pattern does not parse.
    private static let pubDateFallbackFormatters: [DateFormatter] = [
        "EEE, dd MMM yyyy HH:mm:ss zzz",
        "EEE, dd MMM yyyy HH:mm Z",
        "EEE, dd MMM yyyy HH:mm zzz"
    ].map { pattern in
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = pattern
        return f
    }

    nonisolated(unsafe) private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    init(data: Data, podcastId: String) {
        self.data = data
        self.podcastId = podcastId
    }

    private static let parseLogger = Logger(subsystem: "com.Tazk.Lyttejeger", category: "RSSParser")

    func parse() -> PodcastFeedResult {
        let parser = XMLParser(data: data)
        parser.delegate = self
        if !parser.parse() {
            Self.parseLogger.warning("XML parse failed for \(self.podcastId): \(parser.parserError?.localizedDescription ?? "unknown")")
        }

        return PodcastFeedResult(
            podcastTitle: channelTitle,
            podcastDescription: channelDescription,
            podcastImageUrl: channelImageUrl,
            episodes: episodes
        )
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        textBuffer = ""

        if inChannel && !inItem,
           elementName == "image" || elementName == "textInput" || elementName.hasSuffix(":liveItem") {
            channelSubElementDepth += 1
        }

        switch elementName {
        case "channel":
            inChannel = true
        case "item":
            inItem = true
            currentTitle = ""
            currentDescription = ""
            currentAudioUrl = ""
            currentDuration = ""
            currentPubDate = ""
            currentImageUrl = ""
            currentGuid = ""
        case "enclosure":
            if inItem {
                currentAudioUrl = attributeDict["url"] ?? ""
            }
        case "itunes:image":
            if let href = attributeDict["href"] {
                if inItem {
                    currentImageUrl = href
                } else if inChannel && channelSubElementDepth == 0 {
                    channelImageUrl = href
                }
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        textBuffer += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let str = String(data: CDATABlock, encoding: .utf8) {
            textBuffer += str
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        let text = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

        if inItem {
            switch elementName {
            case "title": currentTitle = text
            case "description": currentDescription = text
            case "guid": currentGuid = text
            case "itunes:duration": currentDuration = text
            case "pubDate": currentPubDate = text
            case "item":
                guard episodes.count < AppConstants.maxFeedEpisodes else {
                    inItem = false
                    break
                }
                let episode = Episode(
                    // A feed without a guid still needs a stable per-episode id. The
                    // enclosure URL survives feed updates; a positional index does not
                    // (a new episode at the top renumbers every row, re-attaching saved
                    // progress and queue items to the wrong episode), so position is the
                    // last resort for items that lack both.
                    id: currentGuid.isEmpty
                        ? (currentAudioUrl.isEmpty ? "\(podcastId)-\(episodes.count)" : "\(podcastId)-\(currentAudioUrl)")
                        : currentGuid,
                    podcastId: podcastId,
                    title: currentTitle,
                    description: currentDescription,
                    audioUrl: currentAudioUrl,
                    duration: Self.parseDuration(currentDuration),
                    publishedAt: Self.parseDate(currentPubDate),
                    imageUrl: currentImageUrl.isEmpty ? nil : currentImageUrl
                )
                episodes.append(episode)
                inItem = false
            default:
                break
            }
        } else if inChannel {
            switch elementName {
            case "title" where channelSubElementDepth == 0: channelTitle = text
            case "description" where channelSubElementDepth == 0: channelDescription = text
            case "channel": inChannel = false
            default:
                break
            }
        }

        if inChannel && !inItem,
           elementName == "image" || elementName == "textInput" || elementName.hasSuffix(":liveItem") {
            channelSubElementDepth = max(0, channelSubElementDepth - 1)
        }
    }

    // MARK: - Duration Parsing

    /// Parses "HH:MM:SS" or "MM:SS" to seconds.
    static func parseDuration(_ str: String) -> TimeInterval {
        let parts = str.split(separator: ":").compactMap { Double($0) }
        switch parts.count {
        case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
        case 2: return parts[0] * 60 + parts[1]
        case 1: return parts[0]
        default: return 0
        }
    }

    /// Parses RFC 2822 date (including named-zone and minutes-only variants) to
    /// an ISO 8601 string. Returns "" when nothing parses: the raw English date
    /// string must not leak into the UI, and an empty string drops cleanly out
    /// of date display and date-based filtering.
    static func parseDate(_ str: String) -> String {
        if let date = pubDateFormatter.date(from: str) {
            return isoFormatter.string(from: date)
        }
        for formatter in pubDateFallbackFormatters {
            if let date = formatter.date(from: str) {
                return isoFormatter.string(from: date)
            }
        }
        return ""
    }
}
