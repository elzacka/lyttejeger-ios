import Foundation
import SwiftData

@Observable
@MainActor
final class PlaybackProgressViewModel {
    private var modelContext: ModelContext?

    func setup(_ context: ModelContext) {
        self.modelContext = context
    }

    func getProgress(for episodeId: String) -> PlaybackPosition? {
        guard let modelContext else { return nil }
        let descriptor = FetchDescriptor<PlaybackPosition>(predicate: #Predicate { $0.episodeId == episodeId })
        return try? modelContext.fetch(descriptor).first
    }

    func progressFraction(for episodeId: String) -> Double? {
        guard let position = getProgress(for: episodeId),
              position.duration > 0 else { return nil }
        return position.position / position.duration
    }

    func isCompleted(_ episodeId: String) -> Bool {
        getProgress(for: episodeId)?.completed ?? false
    }

    func clearProgress(for episodeId: String) {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<PlaybackPosition>(predicate: #Predicate { $0.episodeId == episodeId })
        if let positions = try? modelContext.fetch(descriptor) {
            for pos in positions {
                modelContext.delete(pos)
            }
            try? modelContext.save()
        }
    }
}
