import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var searchVM = SearchViewModel()
    @State private var queueVM = QueueViewModel()
    @State private var subscriptionVM = SubscriptionViewModel()
    @State private var playerVM = AudioPlayerViewModel()
    @State private var progressVM = PlaybackProgressViewModel()
    @State private var selectedTab = 0

    private let tabs: [(icon: String, iconFilled: String)] = [
        ("magnifyingglass", "magnifyingglass"),
        ("heart", "heart.fill"),
        ("list.number", "list.number"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Tab content
            ZStack {
                NavigationStack {
                    HomeView()
                }
                .opacity(selectedTab == 0 ? 1 : 0)
                .zIndex(selectedTab == 0 ? 1 : 0)

                NavigationStack {
                    MyPodsView()
                }
                .opacity(selectedTab == 1 ? 1 : 0)
                .zIndex(selectedTab == 1 ? 1 : 0)

                NavigationStack {
                    QueueView()
                }
                .opacity(selectedTab == 2 ? 1 : 0)
                .zIndex(selectedTab == 2 ? 1 : 0)
            }

            // Audio player bar
            if playerVM.currentEpisode != nil {
                AudioPlayerBar()
            }

            // Custom tab bar
            HStack(spacing: 0) {
                ForEach(0..<3) { index in
                    Button {
                        selectedTab = index
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: selectedTab == index ? tabs[index].iconFilled : tabs[index].icon)
                                .font(.system(size: 20, weight: selectedTab == index ? .semibold : .regular))
                                .foregroundStyle(Color.appAccent)

                            // Subtle dot indicator for selected tab
                            Circle()
                                .fill(selectedTab == index ? Color.appAccent : .clear)
                                .frame(width: 4, height: 4)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .contentShape(Rectangle())
                    }
                    .accessibilityLabel(["Søk", "Mine podder", "Kø"][index])
                    .accessibilityAddTraits(selectedTab == index ? .isSelected : [])
                }
            }
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.sm)
            .background(Color.appBackground)
        }
        .background(Color.appBackground)
        .environment(searchVM)
        .environment(queueVM)
        .environment(subscriptionVM)
        .environment(playerVM)
        .environment(progressVM)
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
            navAppearance.largeTitleTextAttributes = [
                .font: UIFont(name: "DMMono-Medium", size: 28) ?? .systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor(Color.appForeground)
            ]
            navAppearance.titleTextAttributes = [
                .font: UIFont(name: "DMMono-Medium", size: 17) ?? .systemFont(ofSize: 17, weight: .semibold),
                .foregroundColor: UIColor(Color.appForeground)
            ]

            UINavigationBar.appearance().standardAppearance = navAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
            UINavigationBar.appearance().compactAppearance = navAppearance
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
