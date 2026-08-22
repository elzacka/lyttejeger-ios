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

    /// Titles the UI tests address the seeded rows by.
    static let seededEpisodeTitles = ["Testepisode 1", "Testepisode 2"]

    static func prepareIfNeeded(_ container: ModelContainer) {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains(resetArgument) || arguments.contains(seedQueueArgument) else { return }

        let context = ModelContext(container)
        try? DataTransferService.deleteAllUserData(in: context)
        DataTransferService.deleteAllUserDefaults()

        guard arguments.contains(seedQueueArgument) else { return }
        seedQueue(in: context)
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
