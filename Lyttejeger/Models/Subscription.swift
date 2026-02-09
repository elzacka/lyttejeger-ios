import Foundation
import SwiftData

@Model
final class Subscription {
    @Attribute(.unique) var podcastId: String
    var title: String
    var author: String
    var imageUrl: String
    var feedUrl: String
    var subscribedAt: Date

    init(
        podcastId: String,
        title: String,
        author: String,
        imageUrl: String,
        feedUrl: String,
        subscribedAt: Date = Date()
    ) {
        self.podcastId = podcastId
        self.title = title
        self.author = author
        self.imageUrl = imageUrl
        self.feedUrl = feedUrl
        self.subscribedAt = subscribedAt
    }
}
