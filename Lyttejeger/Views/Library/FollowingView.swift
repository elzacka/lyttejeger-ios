import SwiftUI

struct FollowingView: View {
    @Environment(SubscriptionViewModel.self) private var subscriptionVM
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Same allowance as `EpisodeCard`.
    private var titleLineLimit: Int {
        dynamicTypeSize.isAccessibilitySize ? 4 : 2
    }

    /// One up at accessibility sizes. Three 106pt columns cannot hold a name
    /// like "Gråsoner - den nye kalde krigen" once the text grows, and two
    /// were still narrow enough to break words mid-word ("Crimina/l"). More
    /// lines does not help; only width does.
    private var columnCount: Int {
        dynamicTypeSize.isAccessibilitySize ? 1 : 3
    }

    private var isSingleColumn: Bool { columnCount == 1 }

    /// Cover and title share a column width so they line up exactly. In a
    /// single column there is no neighbour to line up against, so the title
    /// takes the full row and the cover stays a sensible size.
    private var artworkWidth: CGFloat {
        isSingleColumn ? AppSize.artworkGridWide : AppSize.artworkGrid
    }

    /// Fixed columns rather than adaptive. Adaptive gave each cell more width
    /// than the artwork used, so the title spread wider than the cover above it
    /// and the column read as ragged.
    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: AppSpacing.md, alignment: .top),
            count: columnCount
        )
    }

    /// Multi-column cells reserve their lines so every cover in a row starts
    /// at the same height. A single column has no row to align with, and
    /// capping it there is what truncated the longer names.
    @ViewBuilder
    private func title(_ text: String) -> some View {
        let base = Text(text)
            .font(.smallText)
            .foregroundStyle(Color.appForeground)
            .multilineTextAlignment(.center)

        if isSingleColumn {
            base.frame(maxWidth: .infinity)
        } else {
            base
                .lineLimit(titleLineLimit, reservesSpace: true)
                .frame(width: artworkWidth)
        }
    }

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
                        .foregroundStyle(Color.appMutedForeground)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .center, spacing: AppSpacing.lg) {
                        ForEach(subscriptionVM.subscriptions, id: \.podcastId) { sub in
                            NavigationLink(value: Podcast(subscription: sub)) {
                                VStack(spacing: AppSpacing.sm) {
                                    CachedAsyncImage(url: sub.imageUrl, size: artworkWidth)

                                    // Two lines are reserved whether or not the
                                    // title needs them. Without that a one-line
                                    // title made its cell shorter, and the grid
                                    // centred it, so covers in the same row sat
                                    // at different heights.
                                    title(sub.title)
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
            FollowingView()
        }
    }
}

#Preview("Tom liste") {
    PreviewWrapper {
        NavigationStack {
            FollowingView()
        }
    }
}
#endif
