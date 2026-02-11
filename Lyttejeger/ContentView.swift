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
    @State private var homePath = NavigationPath()
    @State private var myPodsPath = NavigationPath()
    @State private var showMenu = false
    @State private var showPersonvern = false
    @State private var showInnstillinger = false
    @State private var showOmLyttejeger = false

    private let tabs: [(icon: String, iconFilled: String)] = [
        ("house", "house.fill"),
        ("heart", "heart.fill"),
        ("list.number", "list.number"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Tab content
            ZStack {
                NavigationStack(path: $homePath) {
                    HomeView()
                }
                .opacity(selectedTab == 0 ? 1 : 0)
                .zIndex(selectedTab == 0 ? 1 : 0)

                NavigationStack(path: $myPodsPath) {
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
                        if selectedTab == index {
                            // Pop to root on re-tap
                            switch index {
                            case 0: homePath = NavigationPath()
                            case 1: myPodsPath = NavigationPath()
                            default: break
                            }
                        } else {
                            selectedTab = index
                        }
                    } label: {
                        Image(systemName: selectedTab == index ? tabs[index].iconFilled : tabs[index].icon)
                            .font(.system(size: 20, weight: selectedTab == index ? .semibold : .regular))
                            .foregroundStyle(selectedTab == index ? Color.appAccent : Color.appMutedForeground)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(["Hjem", "Mine podder", "Kø"][index])
                    .accessibilityAddTraits(selectedTab == index ? .isSelected : [])
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
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.sm)
            .background(Color.appBackground)
        }
        .background(Color.appBackground)
        .sheet(isPresented: $showMenu) {
            MenuSheet(showPersonvern: $showPersonvern, showInnstillinger: $showInnstillinger, showOmLyttejeger: $showOmLyttejeger)
                .presentationDetents([.height(250)])
        }
        .sheet(isPresented: $showPersonvern) {
            PersonvernView()
        }
        .sheet(isPresented: $showInnstillinger) {
            InnstillingerView()
        }
        .sheet(isPresented: $showOmLyttejeger) {
            OmLyttejegerView()
        }
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

// MARK: - Menu Sheet

private struct MenuSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var showPersonvern: Bool
    @Binding var showInnstillinger: Bool
    @Binding var showOmLyttejeger: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.appBorder)
                .frame(width: 36, height: 5)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.lg)

            VStack(spacing: 0) {
                menuRow("Innstillinger", icon: "gearshape") {
                    dismiss()
                    showInnstillinger = true
                }

                menuDivider

                menuRow("Personvern", icon: "shield.checkered") {
                    dismiss()
                    showPersonvern = true
                }

                menuDivider

                menuRow("Om Lyttejeger", icon: "headphones") {
                    dismiss()
                    showOmLyttejeger = true
                }
            }
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
