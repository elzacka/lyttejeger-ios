import SwiftUI

struct MyPodsView: View {
    @Environment(SubscriptionViewModel.self) private var subscriptionVM

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: AppSpacing.md)
    ]

    var body: some View {
        VStack(spacing: 0) {
            if subscriptionVM.subscriptions.isEmpty {
                Spacer()

                VStack(spacing: AppSpacing.lg) {
                    Image("LaunchLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .opacity(0.4)

                    Text("Ingen podkaster ennå")
                        .font(.bodyText)
                        .foregroundStyle(Color.appMutedForeground)

                    Text("Gå til Hjem og søk etter podkaster")
                        .font(.caption2Text)
                        .foregroundStyle(Color.appBorder)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: AppSpacing.lg) {
                        ForEach(subscriptionVM.subscriptions, id: \.podcastId) { sub in
                            NavigationLink(value: Podcast(subscription: sub)) {
                                VStack(spacing: AppSpacing.sm) {
                                    CachedAsyncImage(url: sub.imageUrl, size: 100)

                                    Text(sub.title)
                                        .font(.caption2Text)
                                        .foregroundStyle(Color.appForeground)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(CardButtonStyle())
                            .accessibilityLabel(sub.title)
                            .contextMenu {
                                Button(role: .destructive) {
                                    subscriptionVM.toggleSubscription(podcast: Podcast(subscription: sub))
                                } label: {
                                    Label("Slutt å følge", systemImage: "heart.slash")
                                }
                            }
                        }
                    }
                    .padding(AppSpacing.lg)
                    .padding(.bottom, AppConstants.playerBottomPadding)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Podcast.self) { podcast in
            PodcastDetailView(podcast: podcast)
        }
        .navigationDestination(for: PodcastRoute.self) { route in
            PodcastDetailView(podcast: route.podcast, focusEpisodeId: route.focusEpisodeId)
        }
    }
}

#if DEBUG
#Preview("Med abonnementer") {
    PreviewWrapper(seeded: true) {
        NavigationStack {
            MyPodsView()
        }
    }
}

#Preview("Tom liste") {
    PreviewWrapper {
        NavigationStack {
            MyPodsView()
        }
    }
}
#endif
