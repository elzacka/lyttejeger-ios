import SwiftUI
import UniformTypeIdentifiers

struct QueueView: View {
    @Environment(QueueViewModel.self) private var queueVM
    @Environment(AudioPlayerViewModel.self) private var playerVM
    @State private var showClearConfirmation = false
    @State private var draggingItemId: String?

    private var queueSummary: String {
        let count = queueVM.items.count
        let episodeWord = count == 1 ? "episode" : "episoder"
        let totalDuration = queueVM.totalDuration
        if totalDuration > 0 {
            return "\(count) \(episodeWord) · \(formatDuration(totalDuration))"
        }
        return "\(count) \(episodeWord)"
    }

    var body: some View {
        VStack(spacing: 0) {
            if !queueVM.items.isEmpty {
                VStack(spacing: AppSpacing.xs) {
                    HStack {
                        Text(queueSummary)
                            .font(.caption2Text)
                            .foregroundStyle(Color.appMutedForeground)
                        Spacer()
                        Button {
                            showClearConfirmation = true
                        } label: {
                            Text("Tøm")
                                .font(.smallText)
                                .foregroundStyle(Color.appMutedForeground)
                                .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                                .contentShape(Rectangle())
                        }
                    }

                    Button {
                        if let first = queueVM.items.first {
                            let episode = first.toEpisode()
                            playerVM.play(episode: episode, podcastTitle: first.podcastTitle, podcastImage: first.podcastImage)
                            queueVM.removeAfterPlay(first)
                        }
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "play.fill")
                                .font(.system(.caption))
                            Text("Spill alle")
                                .font(.buttonText)
                        }
                        .foregroundStyle(Color.appCard)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: AppSize.touchTarget)
                        .padding(.vertical, AppSpacing.xs)
                        .background(Color.appAccent)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    }
                    .accessibilityLabel("Spill alle episoder i køen")
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.sm)
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

                    Text("Trykk og hold på en episode for å legge den til")
                        .font(.caption2Text)
                        .foregroundStyle(Color.appMutedForeground)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(queueVM.items, id: \.episodeId) { item in
                            QueueItemCard(item: item)
                                // Without an explicit preview shape the lift
                                // gets a square system platter behind the
                                // rounded card, which reads as a grey shadow
                                // box around the row being dragged.
                                .contentShape(.dragPreview, RoundedRectangle(cornerRadius: AppRadius.md))
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
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppConstants.playerBottomPadding)
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
            Text(queueVM.items.count == 1
                ? "Episoden i køen vil bli fjernet."
                : "Alle \(queueVM.items.count) episoder i køen vil bli fjernet.")
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
            expandable: true,
            metadataInExpansion: true,
            usePodcastArtwork: true,
            onPlay: {
                playerVM.play(episode: episode, podcastTitle: item.podcastTitle, podcastImage: item.podcastImage)
                queueVM.removeAfterPlay(item)
            },
            useDefaultContextMenu: false,
            // Queue actions live in the row's own menu button. A contextMenu
            // here would make a long press ambiguous with the reorder drag.
            menuContent: { AnyView(queueMenu) }
        )
    }

    @ViewBuilder
    private var queueMenu: some View {
        Button {
            playerVM.play(episode: episode, podcastTitle: item.podcastTitle, podcastImage: item.podcastImage)
            queueVM.removeAfterPlay(item)
        } label: {
            Label("Spill", systemImage: "play.fill")
        }
        if let index = queueVM.items.firstIndex(where: { $0.episodeId == item.episodeId }) {
            if index > 0 {
                Button {
                    queueVM.move(from: IndexSet(integer: index), to: 0)
                } label: {
                    Label("Flytt øverst", systemImage: "arrow.up.to.line")
                }
            }
            if index < queueVM.items.count - 1 {
                Button {
                    queueVM.move(from: IndexSet(integer: index), to: queueVM.items.count)
                } label: {
                    Label("Flytt nederst", systemImage: "arrow.down.to.line")
                }
            }
        }
        Button(role: .destructive) {
            queueVM.remove(item)
        } label: {
            Label("Fjern fra kø", systemImage: "trash")
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
