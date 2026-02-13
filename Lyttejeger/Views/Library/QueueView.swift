import SwiftUI
import UniformTypeIdentifiers

struct QueueView: View {
    @Environment(QueueViewModel.self) private var queueVM
    @Environment(AudioPlayerViewModel.self) private var playerVM
    @State private var showClearConfirmation = false
    @State private var draggingItemId: String?

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
                                .onDrag {
                                    draggingItemId = item.episodeId
                                    return NSItemProvider(object: item.episodeId as NSString)
                                }
                                .onDrop(of: [.text], delegate: QueueDropDelegate(
                                    targetId: item.episodeId,
                                    items: queueVM.items,
                                    draggingItemId: $draggingItemId,
                                    onReorder: { from, to in
                                        queueVM.move(from: IndexSet(integer: from), to: to)
                                    }
                                ))
                                .opacity(draggingItemId == item.episodeId ? 0.4 : 1)
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, 60)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: PodcastRoute.self) { route in
            PodcastDetailView(podcast: route.podcast, focusEpisodeId: route.focusEpisodeId)
        }
        .confirmationDialog("Tøm køen?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("Tøm kø (\(queueVM.items.count))", role: .destructive) {
                queueVM.clearQueue()
            }
        } message: {
            Text("Alle \(queueVM.items.count) episoder i køen vil bli fjernet.")
        }
    }
}

// MARK: - Drop Delegate

private struct QueueDropDelegate: DropDelegate {
    let targetId: String
    let items: [QueueItem]
    @Binding var draggingItemId: String?
    let onReorder: (Int, Int) -> Void

    func performDrop(info: DropInfo) -> Bool {
        draggingItemId = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggingId = draggingItemId,
              draggingId != targetId,
              let fromIndex = items.firstIndex(where: { $0.episodeId == draggingId }),
              let toIndex = items.firstIndex(where: { $0.episodeId == targetId })
        else { return }

        let animation = UIAccessibility.isReduceMotionEnabled ? nil : Animation.easeInOut(duration: 0.2)
        withAnimation(animation) {
            onReorder(fromIndex, toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
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
                    queueVM.move(from: IndexSet(integer: index), to: 0)
                } label: {
                    Label("Flytt øverst", systemImage: "arrow.up.to.line")
                }
            }
            if let index = queueVM.items.firstIndex(where: { $0.episodeId == item.episodeId }),
               index < queueVM.items.count - 1 {
                Button {
                    queueVM.move(from: IndexSet(integer: index), to: queueVM.items.count)
                } label: {
                    Label("Flytt nederst", systemImage: "arrow.down.to.line")
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
