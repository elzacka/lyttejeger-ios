import Foundation

/// One subscription line from an OPML file.
struct OPMLEntry: Sendable, Equatable {
    let title: String
    let feedUrl: String
}

/// Reads and writes OPML, the format podcast apps use to move subscriptions
/// between each other. Apple Podcasts, Overcast, Pocket Casts, Castro and
/// AntennaPod all import and export it, so this is what makes Lyttejeger a
/// place a user can move into and out of.
///
/// Only subscriptions travel in OPML. Queue and playback positions have no
/// representation in the format, so a full backup uses Lyttejeger's own JSON.
enum OPMLService {

    // MARK: - Reading

    /// Extracts subscription entries from OPML data.
    ///
    /// Accepts the loose shapes real exports use: `xmlUrl` is the feed, the
    /// label may be in `text` or `title`, outlines may be nested under
    /// category folders, and non-podcast outlines (no `xmlUrl`) are skipped.
    ///
    /// `completed` is false when the XML parser halted before the end of the
    /// document — a truncated file, or an unescaped `&` mid-file. The entries
    /// collected up to that point are only a prefix of the file, and importing
    /// them as if they were everything told the user a partial migration was
    /// complete.
    static func parse(_ data: Data) -> (entries: [OPMLEntry], completed: Bool) {
        let parser = OPMLParser(data: data)
        return parser.parse()
    }

    // MARK: - Writing

    /// Builds an OPML document from subscriptions.
    static func makeDocument(from subscriptions: [Subscription], generatedAt: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"

        var lines: [String] = [
            #"<?xml version="1.0" encoding="UTF-8"?>"#,
            #"<opml version="2.0">"#,
            "  <head>",
            "    <title>Lyttejeger-abonnementer</title>",
            "    <dateCreated>\(formatter.string(from: generatedAt))</dateCreated>",
            "  </head>",
            "  <body>",
        ]

        for subscription in subscriptions {
            // NRK podcasts followed via a navigation stub carry no feed URL,
            // but their slug is the id, so the URL can be synthesized. Without
            // this every such row silently vanished from the export.
            var feedUrl = subscription.feedUrl
            if feedUrl.isEmpty, subscription.podcastId.hasPrefix("nrk:") {
                feedUrl = Podcast.nrkFeedUrl(slug: String(subscription.podcastId.dropFirst(4)))
            }
            guard !feedUrl.isEmpty else { continue }
            let title = escape(subscription.title)
            let url = escape(feedUrl)
            lines.append(
                #"    <outline type="rss" text="\#(title)" title="\#(title)" xmlUrl="\#(url)"/>"#
            )
        }

        lines.append("  </body>")
        lines.append("</opml>")
        return lines.joined(separator: "\n") + "\n"
    }

    /// Escapes the five XML predefined entities. Attribute values carry
    /// podcast titles, which routinely contain & and quotes.
    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

// MARK: - Parser

private final class OPMLParser: NSObject, XMLParserDelegate {
    private let data: Data
    private var entries: [OPMLEntry] = []
    private var seenFeedUrls = Set<String>()

    init(data: Data) {
        self.data = data
    }

    func parse() -> (entries: [OPMLEntry], completed: Bool) {
        let parser = XMLParser(data: data)
        parser.delegate = self
        // XMLParser halts on the first well-formedness error, keeping whatever
        // was collected before it. That must be reported, not returned as if
        // it were the whole file.
        let completed = parser.parse()
        return (entries, completed)
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String]
    ) {
        guard elementName.lowercased() == "outline" else { return }

        // Attribute names vary in case between exporters
        let attributes = Dictionary(
            attributeDict.map { ($0.key.lowercased(), $0.value) },
            uniquingKeysWith: { first, _ in first }
        )

        // An outline without a feed URL is a category folder, not a podcast
        guard let feedUrl = attributes["xmlurl"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !feedUrl.isEmpty,
              seenFeedUrls.insert(feedUrl).inserted else { return }

        let title = attributes["title"] ?? attributes["text"] ?? ""
        entries.append(OPMLEntry(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            feedUrl: feedUrl
        ))
    }
}
