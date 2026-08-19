import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var searchVM = SearchViewModel()
    @State private var queueVM = QueueViewModel()
    @State private var subscriptionVM = SubscriptionViewModel()
    @State private var playerVM = AudioPlayerViewModel()
    @State private var progressVM = PlaybackProgressViewModel()
    @State private var selectedTab = Tab.home
    @State private var homePath = NavigationPath()
    @State private var myPodsPath = NavigationPath()
    @State private var queuePath = NavigationPath()
    @State private var showMenu = false
    /// Guards the delayed cross-hierarchy push against double taps: two taps
    /// inside the delay used to stack two copies of the same detail screen.
    @State private var routeNavigationTask: Task<Void, Never>?
    @State private var lastPushedRoute: PodcastRoute?

    enum Tab: Int, CaseIterable {
        case home, myPods, queue

        var icon: String {
            switch self {
            case .home: "house"
            case .myPods: "heart"
            case .queue: "list.number"
            }
        }

        var iconFilled: String {
            switch self {
            case .home: "house.fill"
            case .myPods: "heart.fill"
            case .queue: "list.number"
            }
        }

        var label: String {
            switch self {
            case .home: "Hjem"
            case .myPods: "Mine podder"
            case .queue: "Kø"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab content
            ZStack {
                NavigationStack(path: $homePath) {
                    HomeView()
                }
                .opacity(selectedTab == .home ? 1 : 0)
                .zIndex(selectedTab == .home ? 1 : 0)

                NavigationStack(path: $myPodsPath) {
                    MyPodsView()
                }
                .opacity(selectedTab == .myPods ? 1 : 0)
                .zIndex(selectedTab == .myPods ? 1 : 0)

                NavigationStack(path: $queuePath) {
                    QueueView()
                }
                .opacity(selectedTab == .queue ? 1 : 0)
                .zIndex(selectedTab == .queue ? 1 : 0)
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
                    Button {
                        if selectedTab == tab {
                            // Pop to root on re-tap
                            switch tab {
                            case .home: homePath = NavigationPath()
                            case .myPods: myPodsPath = NavigationPath()
                            case .queue: queuePath = NavigationPath()
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

                // Menu divider
                Rectangle()
                    .fill(Color.appBorder.opacity(0.4))
                    .frame(width: 1, height: 24)

                // Menu button
                Button {
                    showMenu = true
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(.title2))
                        .foregroundStyle(Color.appMutedForeground)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppSize.touchTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Meny")
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
        .sheet(isPresented: $showMenu) {
            MenuView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.appBackground)
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
            // dismissing first. A tap on the mini bar can push immediately.
            let needsDismissDelay = playerVM.isExpanded

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
                case .myPods: myPodsPath.append(route)
                case .queue: queuePath.append(route)
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
