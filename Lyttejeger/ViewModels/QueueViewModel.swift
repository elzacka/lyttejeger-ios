import Foundation
import SwiftData

@Observable
@MainActor
final class QueueViewModel {
    private var modelContext: ModelContext?
    var items: [QueueItem] = []

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

        // Check if already in queue
        let episodeId = episode.id
        let descriptor = FetchDescriptor<QueueItem>(predicate: #Predicate { $0.episodeId == episodeId })
        if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty { return }

        let nextPosition = (items.last?.position ?? -1) + 1
        let item = QueueItem(
            episodeId: episode.id,
            podcastId: episode.podcastId,
            title: episode.title,
            episodeDescription: episode.description,
            podcastTitle: podcastTitle,
            audioUrl: episode.audioUrl,
            imageUrl: episode.imageUrl,
            podcastImage: podcastImage,
            duration: episode.duration,
            transcriptUrl: episode.transcriptUrl,
            chaptersUrl: episode.chaptersUrl,
            publishedAt: episode.publishedAt,
            season: episode.season,
            episode: episode.episode,
            position: nextPosition
        )
        modelContext.insert(item)
        try? modelContext.save()
        fetchQueue()
    }

    func playNext(episode: Episode, podcastTitle: String, podcastImage: String?) {
        guard let modelContext else { return }

        // Shift all positions
        for item in items {
            item.position += 1
        }

        let item = QueueItem(
            episodeId: episode.id,
            podcastId: episode.podcastId,
            title: episode.title,
            episodeDescription: episode.description,
            podcastTitle: podcastTitle,
            audioUrl: episode.audioUrl,
            imageUrl: episode.imageUrl,
            podcastImage: podcastImage,
            duration: episode.duration,
            transcriptUrl: episode.transcriptUrl,
            chaptersUrl: episode.chaptersUrl,
            publishedAt: episode.publishedAt,
            season: episode.season,
            episode: episode.episode,
            position: 0
        )
        modelContext.insert(item)
        try? modelContext.save()
        fetchQueue()
    }

    func remove(_ item: QueueItem) {
        guard let modelContext else { return }
        modelContext.delete(item)
        try? modelContext.save()
        fetchQueue()
    }

    func clearQueue() {
        guard let modelContext else { return }
        for item in items {
            modelContext.delete(item)
        }
        try? modelContext.save()
        fetchQueue()
    }

    func move(from source: IndexSet, to destination: Int) {
        var mutableItems = items
        mutableItems.move(fromOffsets: source, toOffset: destination)
        for (index, item) in mutableItems.enumerated() {
            item.position = index
        }
        try? modelContext?.save()
        fetchQueue()
    }

    func popFirst() -> QueueItem? {
        guard let first = items.first else { return nil }
        remove(first)
        return first
    }
}
