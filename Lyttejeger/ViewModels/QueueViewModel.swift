import Foundation
import SwiftData
import os

@Observable
@MainActor
final class QueueViewModel {
    private static let logger = Logger(subsystem: "com.Tazk.Lyttejeger", category: "QueueVM")
    private var modelContext: ModelContext?
    /// Injectable so tests can flip the setting without touching the
    /// simulator's real defaults.
    private let defaults: UserDefaults
    var items: [QueueItem] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func setup(_ context: ModelContext) {
        self.modelContext = context
        fetchQueue()
    }

    func fetchQueue() {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<QueueItem>(sortBy: [SortDescriptor(\.position)])
        items = (try? modelContext.fetch(descriptor)) ?? []
    }

    func addToQueue(episode: Episode, podcastTitle: String, podcastImage: String?) {
        guard let modelContext else { return }

        let episodeId = episode.id
        let descriptor = FetchDescriptor<QueueItem>(predicate: #Predicate { $0.episodeId == episodeId })
        if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty { return }

        let nextPosition = (items.last?.position ?? -1) + 1
        modelContext.insert(makeQueueItem(episode: episode, podcastTitle: podcastTitle, podcastImage: podcastImage, position: nextPosition))
        save()
        fetchQueue()
    }

    func playNext(episode: Episode, podcastTitle: String, podcastImage: String?) {
        guard let modelContext else { return }

        let episodeId = episode.id
        let existingDescriptor = FetchDescriptor<QueueItem>(predicate: #Predicate { $0.episodeId == episodeId })
        if let existing = try? modelContext.fetch(existingDescriptor).first {
            modelContext.delete(existing)
        }

        for item in items { item.position += 1 }

        modelContext.insert(makeQueueItem(episode: episode, podcastTitle: podcastTitle, podcastImage: podcastImage, position: 0))
        save()
        fetchQueue()
    }

    private func makeQueueItem(episode: Episode, podcastTitle: String, podcastImage: String?, position: Int) -> QueueItem {
        QueueItem(
            episodeId: episode.id, podcastId: episode.podcastId,
            title: episode.title, episodeDescription: episode.description,
            podcastTitle: podcastTitle, audioUrl: episode.audioUrl,
            imageUrl: episode.imageUrl, podcastImage: podcastImage,
            duration: episode.duration, transcriptUrl: episode.transcriptUrl,
            chaptersUrl: episode.chaptersUrl, publishedAt: episode.publishedAt,
            season: episode.season, episode: episode.episode,
            position: position
        )
    }

    func remove(_ item: QueueItem) {
        guard let modelContext else { return }
        modelContext.delete(item)
        save()
        fetchQueue()
    }

    func clearQueue() {
        guard let modelContext else { return }
        for item in items {
            modelContext.delete(item)
        }
        save()
        fetchQueue()
    }

    func move(from source: IndexSet, to destination: Int) {
        var mutableItems = items
        mutableItems.move(fromOffsets: source, toOffset: destination)
        for (index, item) in mutableItems.enumerated() {
            item.position = index
        }
        save()
        fetchQueue()
    }

    var totalDuration: TimeInterval {
        items.compactMap(\.duration).reduce(0, +)
    }

    func popFirst() -> (episode: Episode, podcastTitle: String, podcastImage: String?)? {
        guard let first = items.first else { return nil }
        let episode = first.toEpisode()
        let title = first.podcastTitle
        let image = first.podcastImage
        remove(first)
        return (episode, title, image)
    }

    /// The item following `episodeId`, leaving the queue untouched.
    ///
    /// Used by auto-advance while episodes are kept in the queue: the episode
    /// that just finished is still sitting at its position, so taking the first
    /// item would start it over. An episode played from outside the queue is
    /// not in the list, and falls through to the first item.
    func itemAfter(episodeId: String?) -> (episode: Episode, podcastTitle: String, podcastImage: String?)? {
        let next: QueueItem?
        if let episodeId, let index = items.firstIndex(where: { $0.episodeId == episodeId }) {
            next = items.indices.contains(index + 1) ? items[index + 1] : nil
        } else {
            next = items.first
        }
        guard let next else { return nil }
        return (next.toEpisode(), next.podcastTitle, next.podcastImage)
    }

    // MARK: - Behold episoder i køen

    /// The single definition of the setting. It used to be re-read with
    /// `@AppStorage` at four call sites, which is four chances for the rule to
    /// drift and none of them reachable from a test.
    var keepsPlayedEpisodes: Bool {
        defaults.bool(forKey: AppConstants.keepEpisodesInQueueKey)
    }

    /// Takes the item out of the queue unless the listener asked to keep
    /// played episodes. Call this wherever playback starts from a queue row.
    func removeAfterPlay(_ item: QueueItem) {
        guard !keepsPlayedEpisodes else { return }
        remove(item)
    }

    /// What auto-advance should play once `episodeId` finishes.
    ///
    /// Popping the first item is only correct while playing removes episodes
    /// from the queue. With the setting on, the episode that just finished is
    /// still sitting there, so popping would replay it — and remove it, which
    /// is the one thing the setting promises not to do.
    func nextAfterPlaying(episodeId: String?) -> (episode: Episode, podcastTitle: String, podcastImage: String?)? {
        guard keepsPlayedEpisodes else { return popFirst() }
        return itemAfter(episodeId: episodeId)
    }

    private func save() {
        do {
            try modelContext?.save()
        } catch {
            Self.logger.error("Failed to save queue: \(error)")
        }
    }
}
