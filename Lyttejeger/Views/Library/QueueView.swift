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
                    Image(systemName: "headphones")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(Color.appBorder)

                    Text("Ingen episoder i køen")
                        .font(.bodyText)
                        .foregroundStyle(Color.appMutedForeground)
                }

                Spacer()
            } else {
                List {
                    ForEach(queueVM.items, id: \.episodeId) { item in
                        HStack(spacing: AppSpacing.md) {
                            CachedAsyncImage(url: item.podcastImage ?? item.imageUrl, size: 44)

                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text(item.title)
                                    .font(.cardTitle)
                                    .foregroundStyle(Color.appForeground)
                                    .lineLimit(1)

                                Text(item.podcastTitle)
                                    .font(.smallText)
                                    .foregroundStyle(Color.appMutedForeground)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                playerVM.play(episode: item.toEpisode(), podcastTitle: item.podcastTitle, podcastImage: item.podcastImage)
                                queueVM.remove(item)
                            } label: {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(Color.appAccent)
                            }
                            .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                            .accessibilityLabel("Spill \(item.title)")
                        }
                        .listRowBackground(Color.appBackground)
                        .listRowInsets(EdgeInsets(
                            top: AppSpacing.sm,
                            leading: AppSpacing.lg,
                            bottom: AppSpacing.sm,
                            trailing: AppSpacing.lg
                        ))
                        .listRowSeparatorTint(Color.appBorder.opacity(0.4))
                        .swipeActions(edge: .leading) {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                playerVM.play(episode: item.toEpisode(), podcastTitle: item.podcastTitle, podcastImage: item.podcastImage)
                                queueVM.remove(item)
                            } label: {
                                Label("Spill", systemImage: "play.fill")
                            }
                            .tint(Color.appAccent)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                queueVM.remove(item)
                            } label: {
                                Label("Fjern", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button {
                                playerVM.play(episode: item.toEpisode(), podcastTitle: item.podcastTitle, podcastImage: item.podcastImage)
                                queueVM.remove(item)
                            } label: {
                                Label("Spill", systemImage: "play.fill")
                            }
                            Button(role: .destructive) {
                                queueVM.remove(item)
                            } label: {
                                Label("Fjern fra kø", systemImage: "trash")
                            }
                        }
                    }
                    .onMove { source, destination in
                        queueVM.move(from: source, to: destination)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Tøm køen?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("Tøm kø", role: .destructive) {
                queueVM.clearQueue()
            }
        } message: {
            Text("Alle episoder i køen vil bli fjernet.")
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
