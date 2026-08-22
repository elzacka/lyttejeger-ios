import SwiftUI
import SwiftData

extension EnvironmentValues {
    /// False while a view lives in a tab the user is not looking at.
    ///
    /// All four tab hierarchies stay alive, so the inactive ones have to hide
    /// themselves from VoiceOver. ContentView hides the tab roots directly,
    /// but views pushed onto a stack are presented by the NavigationStack and
    /// are out of its reach — they read this instead.
    @Entry var isTabActive: Bool = true
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var searchVM = SearchViewModel()
    @State private var queueVM = QueueViewModel()
    @State private var subscriptionVM = SubscriptionViewModel()
    @State private var playerVM = AudioPlayerViewModel()
    @State private var progressVM = PlaybackProgressViewModel()
    @State private var selectedTab = Tab.home
    @State private var homePath = NavigationPath()
    @State private var followingPath = NavigationPath()
    @State private var queuePath = NavigationPath()
    @State private var menuPath = NavigationPath()
    @State private var pendingImportURL: URL?
    /// Guards the delayed cross-hierarchy push against double taps: two taps
    /// inside the delay used to stack two copies of the same detail screen.
    @State private var routeNavigationTask: Task<Void, Never>?
    @State private var lastPushedRoute: PodcastRoute?

    enum Tab: Int, CaseIterable {
        case home, following, queue, menu

        var icon: String {
            switch self {
            case .home: "house"
            case .following: "heart"
            case .queue: "list.number"
            case .menu: "line.3.horizontal"
            }
        }

        var iconFilled: String {
            switch self {
            case .home: "house.fill"
            case .following: "heart.fill"
            case .queue: "list.number"
            case .menu: "line.3.horizontal"
            }
        }

        var label: String {
            switch self {
            case .home: "Hjem"
            case .following: "Følgeliste"
            case .queue: "Kø"
            case .menu: "Meny"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab content. All four hierarchies stay alive so each tab keeps
            // its scroll position and navigation stack; the inactive ones are
            // hidden from VoiceOver so it cannot reach controls the user
            // cannot see.
            ZStack {
                NavigationStack(path: $homePath) {
                    HomeView()
                        .accessibilityHidden(selectedTab != .home)
                }
                .environment(\.isTabActive, selectedTab == .home)
                .opacity(selectedTab == .home ? 1 : 0)
                .zIndex(selectedTab == .home ? 1 : 0)

                NavigationStack(path: $followingPath) {
                    FollowingView()
                        .accessibilityHidden(selectedTab != .following)
                }
                .environment(\.isTabActive, selectedTab == .following)
                .opacity(selectedTab == .following ? 1 : 0)
                .zIndex(selectedTab == .following ? 1 : 0)

                NavigationStack(path: $queuePath) {
                    QueueView()
                        .accessibilityHidden(selectedTab != .queue)
                }
                .environment(\.isTabActive, selectedTab == .queue)
                .opacity(selectedTab == .queue ? 1 : 0)
                .zIndex(selectedTab == .queue ? 1 : 0)

                NavigationStack(path: $menuPath) {
                    MenuView(pendingImportURL: $pendingImportURL)
                        .accessibilityHidden(selectedTab != .menu)
                }
                .environment(\.isTabActive, selectedTab == .menu)
                .opacity(selectedTab == .menu ? 1 : 0)
                .zIndex(selectedTab == .menu ? 1 : 0)
            }
            .animation(
                UIAccessibility.isReduceMotionEnabled ? nil : .easeInOut(duration: 0.15),
                value: selectedTab
            )

            // Audio player bar
            if playerVM.currentEpisode != nil {
                AudioPlayerBar()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Custom tab bar
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    // Keeps the menu visually apart from the content tabs even
                    // though it now behaves exactly like them.
                    if tab == .menu {
                        Rectangle()
                            .fill(Color.appBorder.opacity(0.4))
                            .frame(width: 1, height: 24)
                    }

                    Button {
                        if selectedTab == tab {
                            // Pop to root on re-tap
                            switch tab {
                            case .home: homePath = NavigationPath()
                            case .following: followingPath = NavigationPath()
                            case .queue: queuePath = NavigationPath()
                            case .menu: menuPath = NavigationPath()
                            }
                        } else {
                            selectedTab = tab
                        }
                    } label: {
                        Image(systemName: selectedTab == tab ? tab.iconFilled : tab.icon)
                            .font(.system(.title2, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundStyle(selectedTab == tab ? Color.appAccent : Color.appMutedForeground)
                            .frame(maxWidth: .infinity)
                            .frame(height: AppSize.touchTarget)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(tab.label)
                    .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                }
            }
            // The full home-indicator inset (34pt) under a label-less row left
            // more empty space than the icons themselves take. The bar reaches
            // into the safe area instead, keeping just enough clearance to stay
            // off the indicator.
            .padding(.bottom, AppSpacing.lg)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.appBorder)
                    .frame(height: 0.5)
            }
            .background(Color.appBackground)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .background(Color.appBackground)
        .animation(
            UIAccessibility.isReduceMotionEnabled ? nil : .easeInOut(duration: 0.2),
            value: playerVM.currentEpisode?.id
        )
        // A file opened from Mail, Files or another podcast app. Import lives
        // in the menu, so send the user there and hand the URL over.
        .onOpenURL { url in
            pendingImportURL = url
            selectedTab = .menu
            menuPath = NavigationPath()
        }
        .environment(searchVM)
        .environment(queueVM)
        .environment(subscriptionVM)
        .environment(playerVM)
        .environment(progressVM)
        .onChange(of: playerVM.pendingPodcastRoute) { _, route in
            guard let route else { return }
            playerVM.pendingPodcastRoute = nil

            // The tab is captured now, not after the sleep: reading it later
            // sent the push to whichever tab the user had switched to during
            // the delay, and forced the Kø tab back to Hjem behind their back.
            let originTab = selectedTab
            // Only the player sheet needs the delay — it has to finish
            // dismissing first. The sheet leaves the dismissal to this
            // handler: when it cleared isExpanded itself, this read always
            // saw false and the delay never applied.
            let needsDismissDelay = playerVM.isExpanded
            if needsDismissDelay {
                playerVM.isExpanded = false
            }

            routeNavigationTask?.cancel()
            routeNavigationTask = Task { @MainActor in
                if needsDismissDelay {
                    try? await Task.sleep(for: .milliseconds(AppConstants.routeNavigationDelayMs))
                    guard !Task.isCancelled else { return }
                }
                guard lastPushedRoute != route else { return }
                lastPushedRoute = route
                switch originTab {
                case .home: homePath.append(route)
                case .following: followingPath.append(route)
                case .queue: queuePath.append(route)
                case .menu: menuPath.append(route)
                }

                // Release the guard shortly after, so the same podcast can be
                // opened again once the user has navigated back. Deliberately
                // its own task: cancelling the push must not strand the guard.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(600))
                    lastPushedRoute = nil
                }
            }
        }
        .onChange(of: selectedTab) { _, _ in
            lastPushedRoute = nil
        }
        .onAppear {
            queueVM.setup(modelContext)
            subscriptionVM.setup(modelContext)
            playerVM.setup(modelContext, queueVM: queueVM)
            progressVM.setup(modelContext)
        }
    }
}

// MARK: - Card Button Style

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(UIAccessibility.isReduceMotionEnabled ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#if DEBUG
#Preview {
    ContentView()
        .modelContainer(previewContainer)
}
#endif
