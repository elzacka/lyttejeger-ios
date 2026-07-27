import Foundation

/// In-memory cache with per-entry TTL and size-capped eviction.
/// Expired entries read as misses; when the cache grows past `maxSize`,
/// the oldest entries (by insertion time) are evicted.
struct TTLCache<Value> {
    private struct Entry {
        let value: Value
        let timestamp: Date
    }

    private var entries: [String: Entry] = [:]
    private let ttl: TimeInterval
    private let maxSize: Int

    init(ttl: TimeInterval, maxSize: Int) {
        self.ttl = ttl
        self.maxSize = maxSize
    }

    /// Returns the cached value if present and not expired.
    func value(for key: String) -> Value? {
        guard let entry = entries[key],
              Date().timeIntervalSince(entry.timestamp) < ttl else { return nil }
        return entry.value
    }

    mutating func insert(_ value: Value, for key: String) {
        entries[key] = Entry(value: value, timestamp: Date())
        guard entries.count > maxSize else { return }
        let sorted = entries.sorted { $0.value.timestamp < $1.value.timestamp }
        for entry in sorted.prefix(entries.count - maxSize) {
            entries.removeValue(forKey: entry.key)
        }
    }

    mutating func removeAll() {
        entries.removeAll()
    }
}
