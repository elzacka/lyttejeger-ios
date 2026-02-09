import Foundation

enum FeatureFlags {
    /// Re-rank search results to boost exact title matches
    static let titleBoost = true

    /// Expand episode search from top 20 to top 50 podcasts
    static let expandedEpisodeSearch = true

    /// Enable chapter playback in audio player
    static let chapters = true

    /// Apply freshness signal to search ranking
    static let freshnessSignal = true

    /// Display season and episode numbers
    static let seasonEpisodeMetadata = true

    /// Enable transcript display
    static let transcripts = true

    /// Store and expose podcast GUID
    static let podcastGuid = true
}
