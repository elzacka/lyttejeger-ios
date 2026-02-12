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
            let nextTime = lastRequestTime.addingTimeInterval(interval)
            try? await Task.sleep(for: .seconds(waitTime))
            lastRequestTime = nextTime
        } else {
            lastRequestTime = now
        }
    }
}
