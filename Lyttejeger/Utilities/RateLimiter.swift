import Foundation

/// Token bucket rate limiter (actor-based for thread safety)
actor RateLimiter {
    private let interval: TimeInterval
    private var lastRequestTime: Date = .distantPast

    init(requestsPerSecond: Double = 1.0) {
        self.interval = 1.0 / requestsPerSecond
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
