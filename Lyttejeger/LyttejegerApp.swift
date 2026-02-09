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
// MARK: - iOS Orientation Support

#if os(iOS)
extension UIDevice {
    static func setOrientation(_ orientation: UIInterfaceOrientationMask) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation))
        }
    }
}
#endif

