import Foundation
import SwiftData

@Model
final class QueueItem {
    var episodeId: String
    var podcastId: String
    var title: String
    var episodeDescription: String?
    var podcastTitle: String
    var audioUrl: String
    var imageUrl: String?
    var podcastImage: String?
    var duration: TimeInterval?
    var transcriptUrl: String?
    var chaptersUrl: String?
    var publishedAt: String?
    var season: Int?
    var episode: Int?
    var addedAt: Date
    var position: Int  // order in queue

    init(
        episodeId: String,
        podcastId: String,
        title: String,
        episodeDescription: String? = nil,
        podcastTitle: String,
        audioUrl: String,
        imageUrl: String? = nil,
        podcastImage: String? = nil,
        duration: TimeInterval? = nil,
        transcriptUrl: String? = nil,
        chaptersUrl: String? = nil,
        publishedAt: String? = nil,
        season: Int? = nil,
        episode: Int? = nil,
        addedAt: Date = Date(),
        position: Int = 0
    ) {
        self.episodeId = episodeId
        self.podcastId = podcastId
        self.title = title
        self.episodeDescription = episodeDescription
        self.podcastTitle = podcastTitle
        self.audioUrl = audioUrl
        self.imageUrl = imageUrl
        self.podcastImage = podcastImage
        self.duration = duration
        self.transcriptUrl = transcriptUrl
        self.chaptersUrl = chaptersUrl
        self.publishedAt = publishedAt
        self.season = season
        self.episode = episode
        self.addedAt = addedAt
        self.position = position
    }

    func toEpisode() -> Episode {
        Episode(
            id: episodeId,
            podcastId: podcastId,
            title: title,
            description: episodeDescription ?? "",
            audioUrl: audioUrl,
            duration: duration ?? 0,
            publishedAt: publishedAt ?? "",
            imageUrl: imageUrl,
            transcriptUrl: transcriptUrl,
            chaptersUrl: chaptersUrl,
            season: season,
            episode: episode
        )
    }
}
