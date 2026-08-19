import SwiftUI

struct ChapterPanel: View {
    @Environment(AudioPlayerViewModel.self) private var playerVM

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()

                Text("Kapitler")
                    .font(.sectionTitle)
                    .foregroundStyle(Color.appForeground)

                Spacer()
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.top, AppSpacing.xl)

            if playerVM.chaptersFailed {
                stateMessage(
                    icon: "exclamationmark.triangle",
                    text: "Kunne ikke laste kapitlene.",
                    retry: { playerVM.retryChapters() }
                )
            } else if playerVM.chapters.isEmpty {
                stateMessage(
                    icon: "list.number",
                    text: "Denne episoden har ingen kapitler.",
                    retry: nil
                )
            } else {

            // Chapter list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(playerVM.chapters) { chapter in
                        Button {
                            playerVM.seekToChapter(chapter)
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                if let img = chapter.img {
                                    CachedAsyncImage(url: img, size: 40)
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
                        .accessibilityLabel("\(chapter.title), \(formatTime(chapter.startTime))\(playerVM.currentChapter?.id == chapter.id ? ", spilles nå" : "")")
                        .accessibilityHint("Trykk for å spole til kapittelet")

                        Divider().padding(.leading, AppSpacing.lg)
                    }
                }
            }
            }
        }
        .background(Color.appBackground)
    }

    /// Shared empty/failure body, so both states look like the same surface.
    @ViewBuilder
    private func stateMessage(icon: String, text: String, retry: (() -> Void)?) -> some View {
        Spacer()

        VStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(.largeTitle, weight: .light))
                .foregroundStyle(retry == nil ? Color.appMutedForeground : Color.appError)

            Text(text)
                .font(.bodyText)
                .foregroundStyle(Color.appMutedForeground)
                .multilineTextAlignment(.center)

            if let retry {
                Button {
                    retry()
                } label: {
                    Text("Prøv igjen")
                        .font(.buttonText)
                        .foregroundStyle(Color.appAccent)
                        .padding(.horizontal, AppSpacing.lg)
                        .frame(minHeight: AppSize.touchTarget)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(AppSpacing.xl)

        Spacer()
    }
}

#if DEBUG
#Preview("Med kapitler") {
    PreviewWrapper(player: .playing) {
        ChapterPanel()
    }
}
#endif
