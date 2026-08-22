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

    /// Waits if needed to respect the rate limit, then claims the slot.
    ///
    /// Throws `CancellationError` if the caller was cancelled while waiting.
    /// That matters: a cancelled caller never sends its request, so returning
    /// normally would let it through anyway, and keeping its slot would make
    /// the next real request wait out a request that never happened. Typing in
    /// the search field cancels a search per keystroke, so at one request per
    /// second that was the whole delay the user felt.
    func acquire() async throws {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastRequestTime)

        guard elapsed < interval else {
            lastRequestTime = now
            return
        }

        let waitTime = interval - elapsed
        // Claim the slot before sleeping, so concurrent callers compute
        // staggered waits instead of all waking at the same moment.
        let reserved = lastRequestTime.addingTimeInterval(interval)
        lastRequestTime = reserved

        do {
            try await Task.sleep(for: .seconds(waitTime))
        } catch {
            // Give the slot back, but only when nothing has queued behind it.
            // Rewinding past a later reservation would let that caller fire
            // sooner than the wait it already computed.
            if lastRequestTime == reserved {
                lastRequestTime = reserved.addingTimeInterval(-interval)
            }
            throw error
        }
    }
}
