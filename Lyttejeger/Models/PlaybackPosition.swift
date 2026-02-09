import Foundation
import SwiftData

@Model
final class PlaybackPosition {
    @Attribute(.unique) var episodeId: String
    var position: TimeInterval  // seconds
    var duration: TimeInterval  // seconds
    var updatedAt: Date
    var completed: Bool  // true if >90% played

    init(
        episodeId: String,
        position: TimeInterval,
        duration: TimeInterval,
        updatedAt: Date = Date(),
        completed: Bool = false
    ) {
        self.episodeId = episodeId
        self.position = position
        self.duration = duration
        self.updatedAt = updatedAt
        self.completed = completed
    }
}
