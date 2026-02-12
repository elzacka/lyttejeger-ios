import SwiftUI
import SwiftData

// Lock orientation to portrait at runtime (Info.plist lists all orientations for App Store validation)
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        BackgroundRefreshService.register()
        return true
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        .portrait
    }
}

@main
struct LyttejegerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                BackgroundRefreshService.scheduleNext()
            }
        }
    }
}

