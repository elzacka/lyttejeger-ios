import BackgroundTasks
import SwiftData

enum BackgroundRefreshService {

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
            await performRefresh()
            sendableTask.value.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
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
            return
        }

        guard !subscriptions.isEmpty else { return }

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

        // Fetch in parallel to warm caches
        await withTaskGroup(of: Void.self) { group in
            if !feedIds.isEmpty {
                group.addTask {
                    _ = try? await PodcastIndexAPI.shared.episodesByFeedIds(feedIds, max: 10)
                }
            }

            for slug in slugs {
                group.addTask {
                    _ = try? await NRKPodcastService.shared.fetchEpisodes(nrkSlug: slug)
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
