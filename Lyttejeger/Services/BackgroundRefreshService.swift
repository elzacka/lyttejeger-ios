import BackgroundTasks
import os
import SwiftData

enum BackgroundRefreshService {
    nonisolated(unsafe) private static let logger = Logger(subsystem: "com.Tazk.Lyttejeger", category: "BackgroundRefresh")

    static func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: AppConstants.backgroundRefreshTaskId,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            handleRefresh(refreshTask)
        }
    }

    static func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: AppConstants.backgroundRefreshTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: AppConstants.backgroundRefreshInterval)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handleRefresh(_ task: BGAppRefreshTask) {
        scheduleNext()

        // BGAppRefreshTask is not Sendable — wrap for safe capture in Task closures
        let sendableTask = UncheckedSendable(task)

        let work = Task {
            logger.info("Background refresh started")
            await performRefresh()
            logger.info("Background refresh completed")
            sendableTask.value.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            logger.warning("Background refresh expired")
            work.cancel()
            sendableTask.value.setTaskCompleted(success: false)
        }
    }

    private static func performRefresh() async {
        // Read subscriptions from a background ModelContainer
        let subscriptions: [(podcastId: String, feedUrl: String)]
        do {
            let container = try ModelContainer(for: QueueItem.self, Subscription.self, PlaybackPosition.self)
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<Subscription>()
            let subs = try context.fetch(descriptor)
            subscriptions = subs.map { (podcastId: $0.podcastId, feedUrl: $0.feedUrl) }
        } catch {
            logger.error("Failed to fetch subscriptions: \(error.localizedDescription)")
            return
        }

        guard !subscriptions.isEmpty else {
            logger.debug("No subscriptions, skipping refresh")
            return
        }

        logger.debug("Refreshing \(subscriptions.count) subscriptions")

        // Split into Podcast Index feeds vs NRK feeds
        var podcastIndexFeedIds: [Int] = []
        var nrkSlugs: [String] = []

        for sub in subscriptions {
            if sub.podcastId.hasPrefix("nrk:") {
                nrkSlugs.append(String(sub.podcastId.dropFirst(4)))
            } else if let feedId = Int(sub.podcastId) {
                podcastIndexFeedIds.append(feedId)
            }
        }

        // Capture as let for Sendable closure compatibility
        let feedIds = podcastIndexFeedIds
        let slugs = nrkSlugs

        // Fetch Podcast Index feeds
        if !feedIds.isEmpty {
            _ = try? await PodcastIndexAPI.shared.episodesByFeedIds(feedIds, max: 10)
        }

        // Fetch NRK feeds with concurrency limit to avoid overwhelming the network
        for batch in stride(from: 0, to: slugs.count, by: AppConstants.nrkConcurrencyLimit) {
            let batchSlugs = Array(slugs[batch..<min(batch + AppConstants.nrkConcurrencyLimit, slugs.count)])
            await withTaskGroup(of: Void.self) { group in
                for slug in batchSlugs {
                    group.addTask {
                        _ = try? await NRKPodcastService.shared.fetchEpisodes(nrkSlug: slug)
                    }
                }
            }
        }
    }
}

/// Wrapper for non-Sendable types that need to cross Task boundaries.
/// Safe when the wrapped value is only accessed from a single Task at a time.
private struct UncheckedSendable<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}
