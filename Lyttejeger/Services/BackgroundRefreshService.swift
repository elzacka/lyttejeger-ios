import BackgroundTasks
import os
import SwiftData

enum BackgroundRefreshService {
    private static let logger = Logger(subsystem: "com.Tazk.Lyttejeger", category: "BackgroundRefresh")

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
        // Thread-safe guard: setTaskCompleted must only be called once per task.
        // The lock must be local: a static would keep its true state for the whole
        // process, so a refresh delivered to a resumed (suspended) process would
        // never call setTaskCompleted and get the app watchdog-killed.
        let completed = OSAllocatedUnfairLock(initialState: false)

        let work = Task {
            logger.info("Background refresh started")
            await performRefresh()
            logger.info("Background refresh completed")
            let alreadyDone = completed.withLock { val -> Bool in
                if val { return true }
                val = true
                return false
            }
            guard !alreadyDone else { return }
            sendableTask.value.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            logger.warning("Background refresh expired")
            work.cancel()
            let alreadyDone = completed.withLock { val -> Bool in
                if val { return true }
                val = true
                return false
            }
            guard !alreadyDone else { return }
            sendableTask.value.setTaskCompleted(success: false)
        }
    }

    /// Splits stored podcast ids into Podcast Index feed ids and NRK slugs.
    /// Ids that are neither — "feed:<url>" from OPML import, or malformed —
    /// are dropped: the refresh has no way to fetch them.
    static func splitSubscriptionIds(_ podcastIds: [String]) -> (feedIds: [Int], nrkSlugs: [String]) {
        var feedIds: [Int] = []
        var nrkSlugs: [String] = []
        for id in podcastIds {
            if id.hasPrefix("nrk:") {
                nrkSlugs.append(String(id.dropFirst(4)))
            } else if let feedId = Int(id) {
                feedIds.append(feedId)
            }
        }
        return (feedIds, nrkSlugs)
    }

    private static func performRefresh() async {
        // Read subscriptions from a background ModelContainer
        let subscriptions: [(podcastId: String, feedUrl: String)]
        do {
            // Same schema and migration plan as the main app
            let container = try LyttejegerStore.makeContainer()
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

        // Split into Podcast Index feeds vs NRK feeds; let-bound tuple members
        // double as the Sendable closure captures below.
        let (feedIds, slugs) = splitSubscriptionIds(subscriptions.map(\.podcastId))

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
