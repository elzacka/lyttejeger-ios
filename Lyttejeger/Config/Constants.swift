import Foundation

enum AppConstants {
    // MARK: - Timing

    /// Search input debounce (seconds)
    static let searchDebounce: TimeInterval = 0.3

    /// Playback position save interval (seconds)
    static let playbackSaveInterval: TimeInterval = 5.0

    // MARK: - Cache

    /// API response cache TTL (seconds) - per Podcast Index ToS
    static let apiCacheTTL: TimeInterval = 5 * 60

    /// Chapter cache TTL (seconds)
    static let chapterCacheTTL: TimeInterval = 30 * 60

    /// Max API cache entries
    static let apiCacheMaxSize = 100

    /// Max chapter cache entries
    static let chapterCacheMaxSize = 50

    // MARK: - Rate Limiting

    /// Min interval between API requests (seconds)
    static let podcastIndexRateLimit: TimeInterval = 1.0

    /// Max retry attempts
    static let apiMaxRetries = 3

    /// Base delay for exponential backoff (seconds)
    static let apiRetryBaseDelay: TimeInterval = 1.0

    // MARK: - Audio

    /// Skip backward (seconds)
    static let skipBackward: TimeInterval = 10

    /// Skip forward (seconds)
    static let skipForward: TimeInterval = 30

    /// Available playback speeds
    static let playbackSpeeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    /// Sleep timer options (minutes, -1 = end of episode, 0 = off)
    static let sleepTimerOptions: [(value: Int, label: String)] = [
        (0, "Av"),
        (15, "15 min"),
        (30, "30 min"),
        (45, "45 min"),
        (60, "1 time"),
        (-1, "Slutten"),
    ]

    // MARK: - UI

    /// Episodes per page
    static let episodesPerPage = 100

    /// Max description length before truncation
    static let maxDescriptionLength = 300

    // MARK: - API

    static let apiBase = "https://api.podcastindex.org/api/1.0"
    static let appName = "Lyttejeger"
    static let appVersion = "1.0.0"

    /// Default allowed language codes
    static let allowedLanguagesAPI = "no,nb,nn,da,sv,en"
}
