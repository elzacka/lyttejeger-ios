import SwiftUI
import SwiftData

// Lock orientation to portrait at runtime (Info.plist lists all orientations for App Store validation)
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        BackgroundRefreshService.register()
        configureNavigationBarAppearance()
        return true
    }

    private func configureNavigationBarAppearance() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundColor = UIColor(Color.appBackground)
        navAppearance.shadowColor = nil
        let largeTitleFont = UIFont(name: "DMMono-Medium", size: 28) ?? .systemFont(ofSize: 28, weight: .bold)
        let titleFont = UIFont(name: "DMMono-Medium", size: 17) ?? .systemFont(ofSize: 17, weight: .semibold)
        navAppearance.largeTitleTextAttributes = [
            .font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: largeTitleFont),
            .foregroundColor: UIColor(Color.appForeground)
        ]
        navAppearance.titleTextAttributes = [
            .font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: titleFont),
            .foregroundColor: UIColor(Color.appForeground)
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
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

    /// Built once. `.modelContainer(for:)` has no migrationPlan overload, so the
    /// container is constructed explicitly and handed to the scene.
    private let modelContainer: ModelContainer = {
        do {
            return try LyttejegerStore.makeContainer()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // Runs before the first view reads the store, and only when the UI
        // test suite asked for a known starting point.
        #if DEBUG
        UITestSupport.prepareIfNeeded(modelContainer)
        #endif
    }

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
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                BackgroundRefreshService.scheduleNext()
            }
        }
    }
}

