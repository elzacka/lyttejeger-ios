import Foundation
import SwiftData
import os

@Observable
@MainActor
final class PlaybackProgressViewModel {
    private static let logger = Logger(subsystem: "com.Tazk.Lyttejeger", category: "PlaybackProgressVM")
    private var modelContext: ModelContext?

    func setup(_ context: ModelContext) {
        self.modelContext = context
        cleanupOldPositions()
    }

    private func cleanupOldPositions() {
        guard let modelContext else { return }

        let completedCutoff = Date().addingTimeInterval(TimeInterval(-AppConstants.completedPositionRetentionDays * 24 * 3600))
        let incompleteCutoff = Date().addingTimeInterval(TimeInterval(-AppConstants.incompletePositionRetentionDays * 24 * 3600))

        // Purge completed positions older than 90 days
        let completedDescriptor = FetchDescriptor<PlaybackPosition>(
            predicate: #Predicate { $0.completed == true && $0.updatedAt < completedCutoff }
        )
        // Purge incomplete positions older than 180 days (prevents unbounded growth)
        let incompleteDescriptor = FetchDescriptor<PlaybackPosition>(
            predicate: #Predicate { $0.completed == false && $0.updatedAt < incompleteCutoff }
        )

        var didChange = false
        if let old = try? modelContext.fetch(completedDescriptor), !old.isEmpty {
            old.forEach { modelContext.delete($0) }
            didChange = true
        }
        if let old = try? modelContext.fetch(incompleteDescriptor), !old.isEmpty {
            old.forEach { modelContext.delete($0) }
            didChange = true
        }

        guard didChange else { return }
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Failed to save playback progress: \(error)")
        }
    }

    func getProgress(for episodeId: String) -> PlaybackPosition? {
        guard let modelContext else { return nil }
        let descriptor = FetchDescriptor<PlaybackPosition>(predicate: #Predicate { $0.episodeId == episodeId })
        return try? modelContext.fetch(descriptor).first
    }

    struct ProgressInfo {
        let fraction: Double?
        let completed: Bool
    }

    /// Single-fetch method that returns both fraction and completion status
    func progressInfo(for episodeId: String) -> ProgressInfo {
        let pos = getProgress(for: episodeId)
        let fraction: Double? = if let pos, pos.duration > 0 { pos.position / pos.duration } else { nil }
        return ProgressInfo(fraction: fraction, completed: pos?.completed ?? false)
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
            do {
                try modelContext.save()
            } catch {
                Self.logger.error("Failed to save playback progress: \(error)")
            }
        }
    }
}
