import SwiftUI
import SwiftData

@main
struct LyttejegerApp: App {
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()

                if showSplash {
                    SplashScreenView {
                        showSplash = false
                    }
                }
            }
            .preferredColorScheme(.light)
        }
        .modelContainer(for: [QueueItem.self, Subscription.self, PlaybackPosition.self])
    }
}

