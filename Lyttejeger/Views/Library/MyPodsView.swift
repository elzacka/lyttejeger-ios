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
                    Image(systemName: "heart")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(Color.appBorder)

                    Text("Ingen podkaster ennå")
                        .font(.bodyText)
                        .foregroundStyle(Color.appMutedForeground)
                }

                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                        ForEach(subscriptionVM.subscriptions, id: \.podcastId) { sub in
                            NavigationLink(value: Podcast(
                                id: sub.podcastId,
                                title: sub.title,
                                author: sub.author,
                                description: "",
                                imageUrl: sub.imageUrl,
                                feedUrl: sub.feedUrl,
                                categories: [],
                                language: "",
                                episodeCount: 0,
                                lastUpdated: "",
                                rating: 0,
                                explicit: false
                            )) {
                                VStack(spacing: AppSpacing.sm) {
                                    CachedAsyncImage(url: sub.imageUrl, size: 100)

                                    Text(sub.title)
                                        .font(.smallText)
                                        .foregroundStyle(Color.appForeground)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .buttonStyle(CardButtonStyle())
                            .accessibilityLabel(sub.title)
                        }
                    }
                    .padding(AppSpacing.lg)
                    .padding(.bottom, 100)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Podcast.self) { podcast in
            PodcastDetailView(podcast: podcast)
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
