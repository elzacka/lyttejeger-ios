import SwiftUI

struct QueueView: View {
    @Environment(QueueViewModel.self) private var queueVM
    @Environment(AudioPlayerViewModel.self) private var playerVM
    @State private var showClearConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            if !queueVM.items.isEmpty {
                HStack {
                    Spacer()
                    Button("Tøm") {
                        showClearConfirmation = true
                    }
                    .font(.buttonText)
                    .foregroundStyle(Color.appError)
                    .frame(minHeight: AppSize.touchTarget)
                }
                .padding(.horizontal, AppSpacing.lg)
            }

            if queueVM.items.isEmpty {
                Spacer()

                VStack(spacing: AppSpacing.lg) {
                    Image("LaunchLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .opacity(0.4)

                    Text("Ingen episoder i køen")
                        .font(.bodyText)
                        .foregroundStyle(Color.appMutedForeground)
                }

                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(queueVM.items, id: \.episodeId) { item in
                            QueueItemCard(item: item)
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, 100)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Tøm køen?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("Tøm kø (\(queueVM.items.count))", role: .destructive) {
                queueVM.clearQueue()
            }
        } message: {
            Text("Alle \(queueVM.items.count) episoder i køen vil bli fjernet.")
        }
    }
}

// MARK: - Queue Item Card

private struct QueueItemCard: View {
    let item: QueueItem

    @Environment(AudioPlayerViewModel.self) private var playerVM
    @Environment(QueueViewModel.self) private var queueVM

    private var episode: Episode { item.toEpisode() }

    var body: some View {
        EpisodeCard(
            episode: episode,
            podcastTitle: item.podcastTitle,
            podcastImage: item.podcastImage ?? "",
            onPlay: {
                playerVM.play(episode: episode, podcastTitle: item.podcastTitle, podcastImage: item.podcastImage)
                queueVM.remove(item)
            },
            useDefaultContextMenu: false
        )
        .contextMenu {
            Button {
                playerVM.play(episode: episode, podcastTitle: item.podcastTitle, podcastImage: item.podcastImage)
                queueVM.remove(item)
            } label: {
                Label("Spill", systemImage: "play.fill")
            }
            if let index = queueVM.items.firstIndex(where: { $0.episodeId == item.episodeId }), index > 0 {
                Button {
                    queueVM.move(from: IndexSet(integer: index), to: index - 1)
                } label: {
                    Label("Flytt opp", systemImage: "arrow.up")
                }
            }
            if let index = queueVM.items.firstIndex(where: { $0.episodeId == item.episodeId }), index < queueVM.items.count - 1 {
                Button {
                    queueVM.move(from: IndexSet(integer: index), to: index + 2)
                } label: {
                    Label("Flytt ned", systemImage: "arrow.down")
                }
            }
            Button(role: .destructive) {
                queueVM.remove(item)
            } label: {
                Label("Fjern fra kø", systemImage: "trash")
            }
        }
    }
}

#if DEBUG
#Preview("Med episoder") {
    PreviewWrapper(seeded: true) {
        NavigationStack {
            QueueView()
        }
    }
}

#Preview("Tom kø") {
    PreviewWrapper {
        NavigationStack {
            QueueView()
        }
    }
}
#endif
