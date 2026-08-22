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

    /// Max Retry-After header value to honor (seconds)
    static let apiRetryAfterMaxSeconds: TimeInterval = 30

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

    // MARK: - Search

    /// Min characters before search triggers
    static let minSearchQueryLength = 2

    /// Max search query length
    static let maxSearchQueryLength = 200

    /// Default search result limit.
    /// The search endpoints cannot filter by language or category server-side,
    /// so these caps are deliberately generous: narrowing happens client-side
    /// and needs enough candidates to work with. API allows up to 1000.
    static let searchResultsDefault = 200

    /// Search result limit when category filter is active. Higher than the
    /// default because category narrowing discards most of the response.
    static let searchResultsWithCategory = 400

    /// Max podcasts to check for episode search
    static let episodeSearchPodcastLimit = 50

    /// Result limit when browsing with filters but no query.
    static let browseResultsDefault = 100

    /// Browse limit when a category filter is active. Trending treats `cat` as
    /// a hint and returns feeds outside the category, and the narrowing is
    /// redone client-side, so the response has to be large enough to survive it.
    static let browseResultsWithCategory = 200

    /// Max subscriptions accepted from one OPML import.
    /// Each unresolved feed costs one rate-limited request, so a 500-podcast
    /// file would otherwise hold the UI for eight minutes. Anything beyond
    /// this is reported as skipped rather than dropped silently.
    static let opmlImportLimit = 200

    /// Max OR alternatives sent to the API.
    /// Podcast Index has no OR syntax, so each alternative costs one request
    /// and the rate limiter spaces requests one second apart. Capped to keep
    /// a deliberately broad query from stalling the UI.
    static let maxOrBranches = 3

    // MARK: - Image Cache

    /// Max images in memory cache
    static let imageCacheCountLimit = 100

    /// Max memory for image cache (bytes)
    static let imageCacheMemoryLimit = 30 * 1024 * 1024

    // MARK: - Data Retention

    /// Days to keep completed playback positions
    static let completedPositionRetentionDays = 90

    /// Days to keep incomplete (in-progress) playback positions
    static let incompletePositionRetentionDays = 180

    /// Fraction of episode duration to consider "completed"
    static let completionThreshold: Double = 0.9

    // MARK: - Transcript

    /// Max transcript download size (bytes)
    static let maxTranscriptSize = 5 * 1024 * 1024

    /// Max transcript cache entries
    static let transcriptCacheMaxSize = 30

    /// Max chapters download size (bytes). Chapter files are small JSON; the
    /// cap is here so a wrong URL cannot pull an arbitrary payload into memory.
    static let maxChaptersSize = 1 * 1024 * 1024

    /// Max artwork download size (bytes). Artwork URLs come from feeds, so the
    /// same rule applies as for chapters and transcripts.
    static let maxArtworkSize = 5 * 1024 * 1024

    // MARK: - Layout

    /// Bottom padding for scroll content (accounts for mini player)
    static let playerBottomPadding: CGFloat = 100

    // MARK: - Background Refresh

    /// BGTaskScheduler task identifier
    static let backgroundRefreshTaskId = "com.Tazk.Lyttejeger.refresh"

    /// Earliest interval between background refreshes (seconds)
    static let backgroundRefreshInterval: TimeInterval = 60 * 60

    /// Max concurrent NRK feed fetches during background refresh
    static let nrkConcurrencyLimit = 4

    /// Max episodes to parse from a podcast RSS feed
    static let maxFeedEpisodes = 500

    /// Max RSS feed download size (bytes). Direct-feed URLs come from imported
    /// OPML files, so the fetch needs the same cap as chapters and transcripts.
    static let maxFeedSize = 10 * 1024 * 1024

    /// Valid pattern for NRK slugs (alphanumeric, underscores, hyphens)
    static let nrkSlugPattern = "^[a-zA-Z0-9_-]+$"

    /// Base URL for NRK RSS feeds (sindrel/nrk-pod-feeds)
    static let nrkFeedBaseURL = "https://sindrel.github.io/nrk-pod-feeds/rss/"

    // MARK: - Player Status Polling

    /// Interval between AVPlayer status polls (milliseconds)
    static let statusPollingIntervalMs: UInt64 = 100

    /// Max polling attempts before timeout (300 × 100ms = 30s)
    static let statusPollingMaxAttempts = 300

    // MARK: - Navigation

    /// Delay for route navigation after fullScreenCover dismissal (milliseconds)
    static let routeNavigationDelayMs: UInt64 = 400

    /// Delay between queue auto-advance episodes (seconds)
    static let autoAdvanceDelay: TimeInterval = 3.0

    /// Sleep timer fade-out duration (seconds)
    static let sleepFadeDuration: TimeInterval = 30.0

    /// Pause duration threshold for smart resume rewind (seconds)
    static let smartResumeThreshold: TimeInterval = 300.0

    /// Smart resume rewind amount (seconds)
    static let smartResumeRewind: TimeInterval = 10.0

    // MARK: - UserDefaults Keys

    static let lastPlayedInfoKey = "lastPlayedInfo"
    static let showLastPlayedKey = "showLastPlayed"
    static let showNewFromSubscriptionsKey = "showNewFromSubscriptions"
    static let podcastSpeedPrefsKey = "podcastSpeedPrefs"
    static let keepEpisodesInQueueKey = "keepEpisodesInQueue"

    /// Effective defaults for the toggles above, in one place. `@AppStorage`
    /// does not persist its default, so anything exporting or reading these
    /// keys directly must apply the same default as the UI — reading a raw
    /// `bool(forKey:)` backed up "false" for toggles the user never touched.
    static let showLastPlayedDefault = true
    static let showNewFromSubscriptionsDefault = true
    static let keepEpisodesInQueueDefault = false

    /// Every key above that holds something the user put there, in one place.
    /// "Slett alle data" walks this list, so a new key is cleared by being
    /// added here rather than by remembering to touch a second file — which is
    /// exactly what was forgotten when `keepEpisodesInQueue` was introduced.
    static let userDataDefaultsKeys = [
        lastPlayedInfoKey,
        showLastPlayedKey,
        showNewFromSubscriptionsKey,
        podcastSpeedPrefsKey,
        keepEpisodesInQueueKey
    ]

    // MARK: - API

    static let apiBase = "https://api.podcastindex.org/api/1.0"
    static let appName = "Lyttejeger"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
}
