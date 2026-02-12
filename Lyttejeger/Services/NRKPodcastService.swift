import Foundation

// MARK: - NRK Catalog Entry (matches podcasts.json)

struct NRKCatalogEntry: Decodable, Sendable {
    let id: String
    let title: String
    let season: String?
    let enabled: Bool
    let ignore: Bool?
    let hidden: Bool?
}

// MARK: - NRK Feed Result

struct NRKFeedResult: Sendable {
    let podcastTitle: String
    let podcastDescription: String
    let podcastImageUrl: String
    let episodes: [Episode]
}

// MARK: - Service

actor NRKPodcastService {
    static let shared = NRKPodcastService()

    private static let catalogURL = "https://raw.githubusercontent.com/sindrel/nrk-pod-feeds/master/podcasts.json"
    private static let feedBaseURL = "https://sindrel.github.io/nrk-pod-feeds/rss/"

    private static let catalogTTL: TimeInterval = 24 * 60 * 60   // 24 hours
    private static let feedTTL: TimeInterval = 30 * 60            // 30 minutes

    private var catalog: [NRKCatalogEntry] = []
    private var catalogFetchedAt: Date?

    private var feedCache: [String: (result: NRKFeedResult, fetchedAt: Date)] = [:]

    // MARK: - Catalog

    /// Ensures the catalog is loaded and returns active entries.
    func ensureCatalog() async throws -> [NRKCatalogEntry] {
        if let fetched = catalogFetchedAt,
           Date().timeIntervalSince(fetched) < Self.catalogTTL,
           !catalog.isEmpty {
            return catalog
        }

        guard let url = URL(string: Self.catalogURL) else {
            throw NRKError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NRKError.fetchFailed
        }

        let entries = try JSONDecoder().decode([NRKCatalogEntry].self, from: data)
        catalog = entries.filter { $0.enabled && $0.ignore != true && $0.hidden != true }
        catalogFetchedAt = Date()
        return catalog
    }

    /// Searches the cached catalog locally by title. Zero network after first load.
    func searchCatalog(query: String) async -> [Podcast] {
        guard !query.isEmpty else { return [] }

        let entries: [NRKCatalogEntry]
        do {
            entries = try await ensureCatalog()
        } catch {
            return []
        }

        let lowered = query.lowercased()
        return entries
            .filter { cleanTitle($0.title).lowercased().contains(lowered) }
            .map { toPodcast($0) }
    }

    // MARK: - RSS Feed

    /// Fetches and parses an NRK podcast's RSS feed, returning metadata + episodes.
    func fetchEpisodes(nrkSlug: String) async throws -> NRKFeedResult {
        // Check cache
        if let cached = feedCache[nrkSlug],
           Date().timeIntervalSince(cached.fetchedAt) < Self.feedTTL {
            return cached.result
        }

        guard let url = URL(string: "\(Self.feedBaseURL)\(nrkSlug).xml") else {
            throw NRKError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NRKError.fetchFailed
        }

        let parser = NRKRSSParser(data: data, podcastId: "nrk:\(nrkSlug)")
        let result = parser.parse()

        feedCache[nrkSlug] = (result: result, fetchedAt: Date())

        // Trim feed cache to 30 entries (LRU)
        if feedCache.count > 30 {
            let oldest = feedCache.sorted { $0.value.fetchedAt < $1.value.fetchedAt }
            for entry in oldest.prefix(feedCache.count - 30) {
                feedCache.removeValue(forKey: entry.key)
            }
        }

        return result
    }

    // MARK: - Mapping

    private func cleanTitle(_ title: String) -> String {
        var t = title
        // Strip "De N siste fra " prefix (N varies: 2, 5, 10, etc.)
        if let range = t.range(of: #"^De \d+ siste fra "#, options: .regularExpression) {
            t = String(t[range.upperBound...])
        }
        return t.trimmingCharacters(in: .whitespaces)
    }

    private func toPodcast(_ entry: NRKCatalogEntry) -> Podcast {
        Podcast(
            id: "nrk:\(entry.id)",
            title: cleanTitle(entry.title),
            author: "NRK",
            description: "",
            imageUrl: "",
            feedUrl: "\(Self.feedBaseURL)\(entry.id).xml",
            categories: [],
            language: "Norsk",
            episodeCount: 0,
            lastUpdated: "",
            explicit: false
        )
    }

    // MARK: - Errors

    enum NRKError: Error, LocalizedError {
        case invalidURL
        case fetchFailed
        case parseFailed

        var errorDescription: String? {
            switch self {
            case .invalidURL: "Ugyldig NRK-URL"
            case .fetchFailed: "Kunne ikke hente NRK-data"
            case .parseFailed: "Kunne ikke tolke NRK-feed"
            }
        }
    }
}

// MARK: - RSS Parser

/// Lightweight RSS 2.0 parser for NRK podcast feeds.
final class NRKRSSParser: NSObject, XMLParserDelegate {
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
    private var currentElement = ""
    private var textBuffer = ""

    private static let pubDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return f
    }()

    nonisolated(unsafe) private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    init(data: Data, podcastId: String) {
        self.data = data
        self.podcastId = podcastId
    }

    func parse() -> NRKFeedResult {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()

        return NRKFeedResult(
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
                } else if inChannel {
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
                let episode = Episode(
                    id: currentGuid.isEmpty ? "nrk-\(episodes.count)" : currentGuid,
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
            case "title": channelTitle = text
            case "description": channelDescription = text
            case "channel": inChannel = false
            default:
                break
            }
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

    /// Parses RFC 2822 date to ISO 8601 string.
    static func parseDate(_ str: String) -> String {
        if let date = pubDateFormatter.date(from: str) {
            return isoFormatter.string(from: date)
        }
        return str
    }
}
