import SwiftUI

struct ChapterPanel: View {
    @Environment(AudioPlayerViewModel.self) private var playerVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Custom header
            HStack {
                Spacer()

                Text("Kapitler")
                    .font(.sectionTitle)
                    .foregroundStyle(Color.appForeground)

                Spacer()
            }
            .overlay(alignment: .trailing) {
                Button("Ferdig") { dismiss() }
                    .font(.buttonText)
                    .foregroundStyle(Color.appAccent)
                    .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.top, AppSpacing.sm)

            // Chapter list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(playerVM.chapters) { chapter in
                        Button {
                            playerVM.seekToChapter(chapter)
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                if let img = chapter.img, let url = URL(string: img) {
                                    AsyncImage(url: url) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Color.appMuted
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(.rect(cornerRadius: AppRadius.sm))
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(chapter.title)
                                        .font(.cardTitle)
                                        .foregroundStyle(
                                            playerVM.currentChapter?.id == chapter.id
                                                ? Color.appAccent
                                                : Color.appForeground
                                        )
                                        .lineLimit(2)

                                    Text(formatTime(chapter.startTime))
                                        .font(.caption2Text)
                                        .foregroundStyle(Color.appMutedForeground)
                                }

                                Spacer()

                                if playerVM.currentChapter?.id == chapter.id {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, AppSpacing.md)
                            .background(
                                playerVM.currentChapter?.id == chapter.id
                                    ? Color.appAccent.opacity(0.08)
                                    : Color.clear
                            )
                        }
                        .accessibilityLabel("\(chapter.title), \(formatTime(chapter.startTime))")

                        Divider().padding(.leading, AppSpacing.lg)
                    }
                }
            }
        }
        .background(Color.appBackground)
    }
}

#if DEBUG
#Preview("Med kapitler") {
    PreviewWrapper(player: .playing) {
        ChapterPanel()
    }
}
#endif
