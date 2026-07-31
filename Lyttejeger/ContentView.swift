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
    @State private var showMenu = false

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

                NavigationStack {
                    QueueView()
                }
                .opacity(selectedTab == .queue ? 1 : 0)
                .zIndex(selectedTab == .queue ? 1 : 0)
            }

            // Audio player bar
            if playerVM.currentEpisode != nil {
                AudioPlayerBar()
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
                            case .queue: break
                            }
                        } else {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: selectedTab == tab ? tab.iconFilled : tab.icon)
                                .font(.system(size: 18, weight: selectedTab == tab ? .semibold : .regular))
                            Text(tab.label)
                                .font(.system(.caption2, weight: selectedTab == tab ? .medium : .regular))
                        }
                        .foregroundStyle(selectedTab == tab ? Color.appAccent : Color.appMutedForeground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
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
                        .font(.system(size: 20))
                        .foregroundStyle(Color.appMutedForeground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Meny")
            }
            .padding(.top, AppSpacing.xs)
            .safeAreaPadding(.bottom)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.appBorder)
                    .frame(height: 0.5)
            }
            .background(Color.appBackground)
        }
        .background(Color.appBackground)
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
            // Delay to allow fullScreenCover dismissal to complete
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(AppConstants.routeNavigationDelayMs))
                switch selectedTab {
                case .home: homePath.append(route)
                case .myPods: myPodsPath.append(route)
                case .queue:
                    selectedTab = .home
                    homePath.append(route)
                }
            }
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
