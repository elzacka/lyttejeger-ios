#if DEBUG
import Foundation
import SwiftData

/// Launch-argument hooks for the XCUITest suite, and nothing else.
///
/// The deterministic UI tests used to assert "either the empty state or some
/// content", because the simulator keeps whatever the previous run left behind.
/// An assertion that accepts both outcomes cannot fail, so it guards nothing.
/// These flags give a test a known starting point instead.
///
/// The whole file is inside `#if DEBUG`: the App Store build is compiled in
/// Release, so none of this can reach a listener's device.
@MainActor
enum UITestSupport {
    /// Empties the store and the app's own defaults before the first screen.
    static let resetArgument = "-uitest-reset"
    /// Puts two known episodes in the queue. Implies a reset.
    static let seedQueueArgument = "-uitest-seed-queue"
    /// Fills the følgeliste. Implies a reset.
    static let seedFollowingArgument = "-uitest-seed-following"

    /// Titles the UI tests address the seeded rows by.
    static let seededEpisodeTitles = ["Testepisode 1", "Testepisode 2"]

    /// Deliberately mixed lengths: the grid's alignment only breaks when one
    /// cell's title wraps to two lines and its neighbour's does not.
    static let seededPodcastTitles = [
        "Ekko",
        "Brønsj og Håndverk",
        "Criminal",
        "Historier Som Endret Norge",
        "Forklart",
        "Gråsoner - den nye kalde krigen",
    ]

    static func prepareIfNeeded(_ container: ModelContainer) {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains(resetArgument)
            || arguments.contains(seedQueueArgument)
            || arguments.contains(seedFollowingArgument) else { return }

        let context = ModelContext(container)
        try? DataTransferService.deleteAllUserData(in: context)
        DataTransferService.deleteAllUserDefaults()

        if arguments.contains(seedQueueArgument) {
            seedQueue(in: context)
        }
        if arguments.contains(seedFollowingArgument) {
            seedFollowing(in: context)
        }
    }

    /// No image URLs: artwork would need the network, and the grid's alignment
    /// is decided by the title lines and the frame, not by what loads into it.
    private static func seedFollowing(in context: ModelContext) {
        for (index, title) in seededPodcastTitles.enumerated() {
            context.insert(
                Subscription(
                    podcastId: "uitest-following-\(index + 1)",
                    title: title,
                    author: "Testforfatter",
                    imageUrl: "",
                    feedUrl: "https://example.invalid/uitest-\(index + 1).xml"
                )
            )
        }
        try? context.save()
    }

    /// The audio URL is deliberately unreachable. These tests are about what
    /// the queue does when playback starts, which is decided on the tap — not
    /// about audio, which no simulator test can assert on anyway.
    private static func seedQueue(in context: ModelContext) {
        for (index, title) in seededEpisodeTitles.enumerated() {
            context.insert(
                QueueItem(
                    episodeId: "uitest-episode-\(index + 1)",
                    podcastId: "uitest-podcast",
                    title: title,
                    episodeDescription: "Beskrivelse av testepisode \(index + 1). Denne teksten finnes bare for at det utvidbare kortet skal ha noe å vise, og den er lang nok til å gå over flere linjer i visningen.",
                    podcastTitle: "Testpodkast",
                    audioUrl: "https://example.invalid/uitest-\(index + 1).mp3",
                    duration: 600,
                    position: index
                )
            )
        }
        try? context.save()
    }
}
#endif
