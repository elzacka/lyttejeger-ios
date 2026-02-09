import Foundation
import SwiftData

@Observable
@MainActor
final class SubscriptionViewModel {
    private var modelContext: ModelContext?
    var subscriptions: [Subscription] = []

    func setup(_ context: ModelContext) {
        self.modelContext = context
        fetchSubscriptions()
    }

    func fetchSubscriptions() {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<Subscription>(sortBy: [SortDescriptor(\.subscribedAt, order: .reverse)])
        subscriptions = (try? modelContext.fetch(descriptor)) ?? []
    }

    func isSubscribed(_ podcastId: String) -> Bool {
        subscriptions.contains { $0.podcastId == podcastId }
    }

    func subscribe(podcast: Podcast) {
        guard let modelContext else { return }
        guard !isSubscribed(podcast.id) else { return }

        let sub = Subscription(
            podcastId: podcast.id,
            title: podcast.title,
            author: podcast.author,
            imageUrl: podcast.imageUrl,
            feedUrl: podcast.feedUrl
        )
        modelContext.insert(sub)
        try? modelContext.save()
        fetchSubscriptions()
    }

    func unsubscribe(_ podcastId: String) {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<Subscription>(predicate: #Predicate { $0.podcastId == podcastId })
        if let subs = try? modelContext.fetch(descriptor) {
            for sub in subs {
                modelContext.delete(sub)
            }
            try? modelContext.save()
            fetchSubscriptions()
        }
    }

    func toggleSubscription(podcast: Podcast) {
        if isSubscribed(podcast.id) {
            unsubscribe(podcast.id)
        } else {
            subscribe(podcast: podcast)
        }
    }
}
