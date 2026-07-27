import Foundation

/// Minimum-interval rate limiter (actor-based for thread safety).
/// Enforces a fixed minimum spacing between requests; concurrent callers
/// are staggered rather than bursting.
actor RateLimiter {
    private let interval: TimeInterval
    private var lastRequestTime: Date = .distantPast

    init(minInterval: TimeInterval) {
        self.interval = minInterval
    }

    /// Wait if needed to respect rate limit, then mark request
    func acquire() async {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastRequestTime)

        if elapsed < interval {
            let waitTime = interval - elapsed
            // Advance lastRequestTime before sleeping so concurrent callers
            // compute staggered waits instead of bursting simultaneously
            lastRequestTime = lastRequestTime.addingTimeInterval(interval)
            try? await Task.sleep(for: .seconds(waitTime))
        } else {
            lastRequestTime = now
        }
    }
}
