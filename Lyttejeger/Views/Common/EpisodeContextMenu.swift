import SwiftUI

struct EpisodeContextMenuModifier: ViewModifier {
    let episode: Episode
    let podcastTitle: String
    let podcastImage: String

    @Environment(AudioPlayerViewModel.self) private var playerVM
    @Environment(QueueViewModel.self) private var queueVM

    func body(content: Content) -> some View {
        content.contextMenu {
            Button {
                playerVM.play(episode: episode, podcastTitle: podcastTitle, podcastImage: podcastImage)
            } label: {
                Label("Spill", systemImage: "play.fill")
            }
            Button {
                queueVM.playNext(episode: episode, podcastTitle: podcastTitle, podcastImage: podcastImage)
            } label: {
                Label("Spill neste", systemImage: "text.insert")
            }
            Button {
                queueVM.addToQueue(episode: episode, podcastTitle: podcastTitle, podcastImage: podcastImage)
            } label: {
                Label("Legg i kø", systemImage: "text.append")
            }
        }
    }
}

extension View {
    func episodeContextMenu(episode: Episode, podcastTitle: String, podcastImage: String) -> some View {
        modifier(EpisodeContextMenuModifier(episode: episode, podcastTitle: podcastTitle, podcastImage: podcastImage))
    }
}
