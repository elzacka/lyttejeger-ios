import Foundation
import SwiftData
import os

/// What an import actually did, so the UI can tell the user rather than
/// leaving them guessing whether anything happened.
struct ImportSummary: Sendable, Equatable {
    var addedSubscriptions = 0
    var skippedSubscriptions = 0
    var addedQueueItems = 0
    var addedPositions = 0
    /// Subscriptions in the file that could not be resolved to a podcast.
    var failedSubscriptions = 0

    var isEmpty: Bool {
        addedSubscriptions == 0 && addedQueueItems == 0 && addedPositions == 0
    }
}

enum ImportError: Error, LocalizedError {
    case unreadableFile
    case unrecognisedFormat

    var errorDescription: String? {
        switch self {
        case .unreadableFile: "Kunne ikke lese filen"
        case .unrecognisedFormat: "Filformatet er ikke støttet"
        }
    }
}

/// Import and export of user data.
///
/// Two formats, because they serve different jobs. OPML moves subscriptions
/// to and from other podcast apps; it is the only format they all agree on,
/// but it carries nothing else. Lyttejeger's own JSON is a full backup:
/// subscriptions, queue, playback positions and the home screen settings.
///
/// Import always merges and never replaces. Someone importing a file from
/// another app expects to gain podcasts, not to lose the ones they already
/// follow, and there is no undo.
enum DataTransferService {

    private static let logger = Logger(subsystem: "com.Tazk.Lyttejeger", category: "DataTransfer")

    // MARK: - Format detection

    enum Format {
        case opml
        case json
    }

    /// Picks the format from the file extension, falling back to sniffing the
    /// contents. Files arriving from other apps and from AirDrop often carry
    /// a generic extension, and some OPML exports are named `.xml`.
    static func detectFormat(url: URL, data: Data) -> Format? {
        switch url.pathExtension.lowercased() {
        case "opml": return .opml
        case "json": return .json
        default: break
        }

        let prefix = String(decoding: data.prefix(1024), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if prefix.hasPrefix("{") { return .json }
        if prefix.lowercased().contains("<opml") { return .opml }
        return nil
    }

    // MARK: - Export

    /// Full backup in Lyttejeger's own format.
    static func makeJSONExport(
        subscriptions: [Subscription],
        queueItems: [QueueItem],
        positions: [PlaybackPosition],
        exportedAt: Date
    ) throws -> Data {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let export: [String: Any] = [
            "app": "Lyttejeger",
            "versjon": AppConstants.appVersion,
            "eksportert": formatter.string(from: exportedAt),
            "abonnementer": subscriptions.map { sub in
                [
                    "podcastId": sub.podcastId,
                    "tittel": sub.title,
                    "forfatter": sub.author,
                    "bildeUrl": sub.imageUrl,
                    "feedUrl": sub.feedUrl,
                    "abonnertDato": formatter.string(from: sub.subscribedAt),
                ] as [String: Any]
            },
            "spillekø": queueItems.map { item in
                // JSONSerialization cannot encode nil, so optional fields are
                // only present when they hold a value; import defaults the rest.
                var entry: [String: Any] = [
                    "episodeId": item.episodeId,
                    "podcastId": item.podcastId,
                    "tittel": item.title,
                    "podkast": item.podcastTitle,
                    "audioUrl": item.audioUrl,
                    "posisjon": item.position,
                    "lagtTil": formatter.string(from: item.addedAt),
                ]
                entry["beskrivelse"] = item.episodeDescription
                entry["bildeUrl"] = item.imageUrl
                entry["podkastBilde"] = item.podcastImage
                entry["varighet"] = item.duration
                entry["transkripsjonUrl"] = item.transcriptUrl
                entry["kapitlerUrl"] = item.chaptersUrl
                entry["publisert"] = item.publishedAt
                entry["sesong"] = item.season
                entry["episodeNr"] = item.episode
                return entry
            },
            "avspillingsposisjoner": positions.map { pos in
                [
                    "episodeId": pos.episodeId,
                    "posisjon": pos.position,
                    "varighet": pos.duration,
                    "fullført": pos.completed,
                    "oppdatert": formatter.string(from: pos.updatedAt),
                ] as [String: Any]
            },
            // Every toggle the user can set. A new one belongs here and in
            // applySettings below, so export and import stay symmetric.
            "innstillinger": [
                "visFortsettÅLytte": UserDefaults.standard.bool(forKey: AppConstants.showLastPlayedKey),
                "visNyttFraAbonnementer": UserDefaults.standard.bool(forKey: AppConstants.showNewFromSubscriptionsKey),
                "beholdEpisoderIKoen": UserDefaults.standard.bool(forKey: AppConstants.keepEpisodesInQueueKey),
            ] as [String: Any],
        ]

        return try JSONSerialization.data(
            withJSONObject: export,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    /// Subscriptions only, for other podcast apps.
    static func makeOPMLExport(subscriptions: [Subscription], exportedAt: Date) -> Data {
        Data(OPMLService.makeDocument(from: subscriptions, generatedAt: exportedAt).utf8)
    }

    // MARK: - Import

    /// Imports a Lyttejeger JSON backup. Everything is matched on its unique
    /// id, so re-importing the same file changes nothing.
    @MainActor
    static func importJSON(_ data: Data, into context: ModelContext) throws -> ImportSummary {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ImportError.unreadableFile
        }
        guard root["abonnementer"] != nil || root["spillekø"] != nil || root["avspillingsposisjoner"] != nil else {
            throw ImportError.unrecognisedFormat
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var summary = ImportSummary()

        // var, not let: an id inserted earlier in this same file has to
        // count as existing, or a file listing a podcast twice reports two
        // additions while @Attribute(.unique) stores one.
        var existingSubscriptionIds = Set(
            ((try? context.fetch(FetchDescriptor<Subscription>())) ?? []).map(\.podcastId)
        )
        for raw in root["abonnementer"] as? [[String: Any]] ?? [] {
            guard let podcastId = raw["podcastId"] as? String, !podcastId.isEmpty else { continue }
            guard !existingSubscriptionIds.contains(podcastId) else {
                summary.skippedSubscriptions += 1
                continue
            }
            context.insert(Subscription(
                podcastId: podcastId,
                title: raw["tittel"] as? String ?? "",
                author: raw["forfatter"] as? String ?? "",
                imageUrl: raw["bildeUrl"] as? String ?? "",
                feedUrl: raw["feedUrl"] as? String ?? "",
                subscribedAt: (raw["abonnertDato"] as? String).flatMap(formatter.date(from:)) ?? Date()
            ))
            existingSubscriptionIds.insert(podcastId)
            summary.addedSubscriptions += 1
        }

        var existingQueueIds = Set(
            ((try? context.fetch(FetchDescriptor<QueueItem>())) ?? []).map(\.episodeId)
        )
        var nextPosition = ((try? context.fetch(FetchDescriptor<QueueItem>())) ?? [])
            .map(\.position).max().map { $0 + 1 } ?? 0
        for raw in root["spillekø"] as? [[String: Any]] ?? [] {
            guard let episodeId = raw["episodeId"] as? String, !episodeId.isEmpty,
                  let audioUrl = raw["audioUrl"] as? String, !audioUrl.isEmpty,
                  !existingQueueIds.contains(episodeId) else { continue }
            let item = QueueItem(
                episodeId: episodeId,
                podcastId: raw["podcastId"] as? String ?? "",
                title: raw["tittel"] as? String ?? "",
                episodeDescription: raw["beskrivelse"] as? String,
                podcastTitle: raw["podkast"] as? String ?? "",
                audioUrl: audioUrl,
                imageUrl: raw["bildeUrl"] as? String,
                podcastImage: raw["podkastBilde"] as? String,
                duration: raw["varighet"] as? TimeInterval,
                transcriptUrl: raw["transkripsjonUrl"] as? String,
                chaptersUrl: raw["kapitlerUrl"] as? String,
                publishedAt: raw["publisert"] as? String,
                season: raw["sesong"] as? Int,
                episode: raw["episodeNr"] as? Int,
                addedAt: (raw["lagtTil"] as? String).flatMap(formatter.date(from:)) ?? Date(),
                position: nextPosition
            )
            context.insert(item)
            existingQueueIds.insert(episodeId)
            nextPosition += 1
            summary.addedQueueItems += 1
        }

        var existingPositionIds = Set(
            ((try? context.fetch(FetchDescriptor<PlaybackPosition>())) ?? []).map(\.episodeId)
        )
        for raw in root["avspillingsposisjoner"] as? [[String: Any]] ?? [] {
            guard let episodeId = raw["episodeId"] as? String, !episodeId.isEmpty,
                  !existingPositionIds.contains(episodeId) else { continue }
            context.insert(PlaybackPosition(
                episodeId: episodeId,
                position: raw["posisjon"] as? TimeInterval ?? 0,
                duration: raw["varighet"] as? TimeInterval ?? 0,
                updatedAt: (raw["oppdatert"] as? String).flatMap(formatter.date(from:)) ?? Date(),
                completed: raw["fullført"] as? Bool ?? false
            ))
            existingPositionIds.insert(episodeId)
            summary.addedPositions += 1
        }

        applySettings(root["innstillinger"] as? [String: Any])

        try saveOrRollback(context)
        return summary
    }

    /// Restores the home screen and queue toggles from a backup.
    ///
    /// Only keys actually present are touched, so an older export that predates
    /// a setting leaves it alone rather than resetting it to false.
    private static func applySettings(_ raw: [String: Any]?) {
        guard let raw else { return }
        let mapping: [(String, String)] = [
            ("visFortsettÅLytte", AppConstants.showLastPlayedKey),
            ("visNyttFraAbonnementer", AppConstants.showNewFromSubscriptionsKey),
            ("beholdEpisoderIKoen", AppConstants.keepEpisodesInQueueKey),
        ]
        for (fileKey, defaultsKey) in mapping {
            if let value = raw[fileKey] as? Bool {
                UserDefaults.standard.set(value, forKey: defaultsKey)
            }
        }
    }

    /// Saves, and discards the whole import if the save fails.
    ///
    /// Without the rollback the context keeps the inserted objects, and the
    /// app's autosaving main context would commit them a moment later — after
    /// the user had already been told the import failed.
    private static func saveOrRollback(_ context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            logger.error("Import save failed, rolled back: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    /// Imports subscriptions from an OPML file exported by another podcast app.
    ///
    /// OPML gives a title and a feed URL and nothing else, so each feed is
    /// resolved through Podcast Index to get the id, artwork and author the
    /// app needs elsewhere. That costs one rate-limited request per feed, so
    /// `progress` is reported as it goes and the count is capped.
    ///
    /// NRK feeds are recognised from their URL and resolved without a request,
    /// since Podcast Index does not index them well.
    @MainActor
    static func importOPML(
        _ data: Data,
        into context: ModelContext,
        api: any PodcastSearching,
        progress: @MainActor (Int, Int) -> Void
    ) async throws -> ImportSummary {
        let entries = OPMLService.parse(data)
        guard !entries.isEmpty else { throw ImportError.unrecognisedFormat }

        let capped = Array(entries.prefix(AppConstants.opmlImportLimit))
        var summary = ImportSummary()
        summary.failedSubscriptions = entries.count - capped.count

        let existing = (try? context.fetch(FetchDescriptor<Subscription>())) ?? []
        var existingIds = Set(existing.map(\.podcastId))
        let existingFeedUrls = Set(existing.map(\.feedUrl).filter { !$0.isEmpty })

        for (index, entry) in capped.enumerated() {
            progress(index + 1, capped.count)

            if existingFeedUrls.contains(entry.feedUrl) {
                summary.skippedSubscriptions += 1
                continue
            }

            guard let subscription = await resolve(entry: entry, api: api) else {
                summary.failedSubscriptions += 1
                continue
            }
            guard existingIds.insert(subscription.podcastId).inserted else {
                summary.skippedSubscriptions += 1
                continue
            }

            context.insert(subscription)
            summary.addedSubscriptions += 1
        }

        try saveOrRollback(context)
        return summary
    }

    /// Turns one OPML line into a Subscription, preferring real metadata.
    @MainActor
    private static func resolve(entry: OPMLEntry, api: any PodcastSearching) async -> Subscription? {
        if let slug = nrkSlug(fromFeedUrl: entry.feedUrl) {
            return Subscription(
                podcastId: "nrk:\(slug)",
                title: entry.title.isEmpty ? slug : entry.title,
                author: "NRK",
                imageUrl: "",
                feedUrl: entry.feedUrl
            )
        }

        if let feed = try? await api.podcastByFeedUrl(entry.feedUrl).feed {
            let podcast = PodcastTransform.transformFeed(feed)
            return Subscription(
                podcastId: podcast.id,
                title: podcast.title.isEmpty ? entry.title : podcast.title,
                author: podcast.author,
                imageUrl: podcast.imageUrl,
                feedUrl: podcast.feedUrl.isEmpty ? entry.feedUrl : podcast.feedUrl
            )
        }

        // Unknown to Podcast Index. Keep the subscription anyway rather than
        // silently dropping it: the feed URL is enough to fetch episodes, and
        // losing a podcast during a migration is worse than missing artwork.
        guard !entry.title.isEmpty else { return nil }
        logger.info("OPML feed not in Podcast Index, keeping by URL")
        return Subscription(
            podcastId: "feed:\(entry.feedUrl)",
            title: entry.title,
            author: "",
            imageUrl: "",
            feedUrl: entry.feedUrl
        )
    }

    // MARK: - Delete

    /// Deletes every stored model. Throws instead of guessing, so the caller
    /// can tell the user whether the deletion actually happened.
    @MainActor
    static func deleteAllUserData(in context: ModelContext) throws {
        try context.delete(model: Subscription.self)
        try context.delete(model: QueueItem.self)
        try context.delete(model: PlaybackPosition.self)
        try context.save()
    }

    /// The other half of "Slett alle data": everything the app keeps outside
    /// the store. It lived in the view, where nothing could check it, and a key
    /// added later was duly forgotten. Driven off `userDataDefaultsKeys` so
    /// adding a key in one place is enough.
    static func deleteAllUserDefaults(in defaults: UserDefaults = .standard) {
        for key in AppConstants.userDataDefaultsKeys {
            defaults.removeObject(forKey: key)
        }
        deleteAllCookies()
    }

    /// Cookies are refused at launch, so this should find nothing. It runs
    /// anyway: a store written by a build from before that guard would
    /// otherwise survive "Slett alle data" indefinitely.
    static func deleteAllCookies(in storage: HTTPCookieStorage = .shared) {
        for cookie in storage.cookies ?? [] {
            storage.deleteCookie(cookie)
        }
    }

    /// Recognises an NRK feed URL and returns its slug.
    static func nrkSlug(fromFeedUrl feedUrl: String) -> String? {
        let marker = "nrk-pod-feeds/rss/"
        guard let range = feedUrl.range(of: marker) else { return nil }
        let tail = feedUrl[range.upperBound...]
        let slug = tail.hasSuffix(".xml") ? String(tail.dropLast(4)) : String(tail)
        guard !slug.isEmpty,
              slug.range(of: AppConstants.nrkSlugPattern, options: .regularExpression) != nil else {
            return nil
        }
        return slug
    }
}
