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
    @State private var showInnstillinger = false
    @State private var showOmLyttejeger = false

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
                        Image(systemName: selectedTab == tab ? tab.iconFilled : tab.icon)
                            .font(.system(size: 20, weight: selectedTab == tab ? .semibold : .regular))
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
            MenuSheet(showInnstillinger: $showInnstillinger, showOmLyttejeger: $showOmLyttejeger)
                .presentationDetents([.height(160)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.appBackground)
        }
        .sheet(isPresented: $showInnstillinger) {
            InnstillingerView()
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.appBackground)
        }
        .sheet(isPresented: $showOmLyttejeger) {
            OmLyttejegerView()
                .presentationDetents([.fraction(0.75)])
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
            playerVM.setup(modelContext)
            progressVM.setup(modelContext)

            // Style navigation bar — for pushed views (detail screens)
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
    }
}

// MARK: - Menu Sheet

private struct MenuSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var showInnstillinger: Bool
    @Binding var showOmLyttejeger: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                menuRow("Innstillinger", icon: "gearshape") {
                    dismiss()
                    showInnstillinger = true
                }

                menuDivider

                menuRow("Om Lyttejeger", icon: "headphones") {
                    dismiss()
                    showOmLyttejeger = true
                }
            }
            .padding(.top, AppSpacing.sm)
        }
        .frame(maxWidth: .infinity)
        .background(Color.appBackground)
    }

    private var menuDivider: some View {
        Rectangle()
            .fill(Color.appBorder.opacity(0.3))
            .frame(height: 1)
            .padding(.horizontal, AppSpacing.lg)
    }

    private func menuRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.appAccent)
                    .frame(width: 24)
                Text(title)
                    .font(.bodyText)
                    .foregroundStyle(Color.appForeground)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appBorder)
            }
            .padding(.horizontal, AppSpacing.xl)
            .frame(height: AppSize.touchTarget)
            .contentShape(Rectangle())
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
