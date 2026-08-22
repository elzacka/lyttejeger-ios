import SwiftUI

struct TranscriptPanel: View {
    @Environment(AudioPlayerViewModel.self) private var playerVM
    @State private var autoScroll = true
    @State private var lastScrolledSegmentId: String?
    /// Tracked per episode, not as a one-shot flag: the panel is reused across
    /// episodes, so a plain "already scrolled" bool left every later episode
    /// opening at the top instead of at the current position.
    @State private var scrolledForEpisodeId: String?

    /// Some publishers ship a transcript with text but no timings. It reads
    /// fine, but nothing in it can follow playback, so the controls that
    /// promise synchronisation are left out rather than shown doing nothing.
    private var isSynced: Bool {
        playerVM.transcript?.isSynced ?? true
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if isSynced {
                    Button {
                        autoScroll.toggle()
                    } label: {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: autoScroll ? "arrow.up.arrow.down" : "hand.draw")
                                .font(.system(.subheadline))
                            Text(autoScroll ? "Auto" : "Manuell")
                                .font(.buttonText)
                        }
                        .foregroundStyle(Color.appAccent)
                        .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                        .contentShape(Rectangle())
                    }
                    .accessibilityLabel(autoScroll ? "Automatisk rulling på" : "Automatisk rulling av")
                } else {
                    Text("Uten tidskoder")
                        .font(.buttonText)
                        .foregroundStyle(Color.appMutedForeground)
                        .frame(minHeight: AppSize.touchTarget)
                }

                Spacer()
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.top, AppSpacing.xl)

            Divider()
                .background(Color.appBorder)

            // Transcript content
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if let transcript = playerVM.transcript {
                            ForEach(transcript.segments) { segment in
                                let isCurrent = isSynced && isCurrentSegment(segment)

                                HStack(alignment: .top, spacing: AppSpacing.sm) {
                                    // Active indicator bar
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .fill(isCurrent ? Color.appAccent : Color.clear)
                                        .frame(width: 3)

                                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                        if let speaker = segment.speaker {
                                            Text(speaker)
                                                .font(.badgeText)
                                                .foregroundStyle(Color.appAccent)
                                        }

                                        Text(segment.text)
                                            .font(.bodyText)
                                            .foregroundStyle(
                                                // Without timings nothing is
                                                // "current", so muting every
                                                // line would mute the whole
                                                // transcript.
                                                isCurrent || !isSynced
                                                    ? Color.appForeground
                                                    : Color.appMutedForeground
                                            )
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, AppSpacing.lg)
                                .padding(.vertical, AppSpacing.md)
                                .background(isCurrent ? Color.appAccent.opacity(0.1) : Color.clear)
                                .id(segment.id)
                                .onTapGesture {
                                    guard isSynced else { return }
                                    playerVM.seek(to: segment.startTime)
                                }
                                .accessibilityLabel(segment.text)
                                .accessibilityAddTraits(isSynced ? [.isButton] : [])
                                .accessibilityHint(isSynced ? "Trykk for å spole til dette tidspunktet" : "")

                                // Divider between segments
                                if segment.id != transcript.segments.last?.id {
                                    Divider()
                                        .background(Color.appBorder.opacity(0.5))
                                        .padding(.leading, AppSpacing.lg + 3 + AppSpacing.sm)
                                }
                            }
                        } else if playerVM.transcriptFailed {
                            VStack(spacing: AppSpacing.md) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(.largeTitle, weight: .light))
                                    .foregroundStyle(Color.appError)

                                Text("Kunne ikke laste transkripsjonen.")
                                    .font(.bodyText)
                                    .foregroundStyle(Color.appMutedForeground)
                                    .multilineTextAlignment(.center)

                                Button {
                                    playerVM.retryTranscript()
                                } label: {
                                    Text("Prøv igjen")
                                        .font(.buttonText)
                                        .foregroundStyle(Color.appAccent)
                                        .padding(.horizontal, AppSpacing.lg)
                                        .frame(minHeight: AppSize.touchTarget)
                                        .contentShape(Rectangle())
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(AppSpacing.xl)
                        } else {
                            Text("Denne episoden har ingen transkripsjon.")
                                .font(.bodyText)
                                .foregroundStyle(Color.appMutedForeground)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                                .padding(AppSpacing.xl)
                        }
                    }
                    .padding(.vertical, AppSpacing.sm)
                }
                .onAppear {
                    scrollToCurrent(using: proxy)
                }
                .onChange(of: playerVM.transcript?.segments.first?.id) { _, _ in
                    // A new episode's transcript just arrived. Reset so it
                    // opens at the listener's position rather than the top.
                    scrolledForEpisodeId = nil
                    lastScrolledSegmentId = nil
                    scrollToCurrent(using: proxy)
                }
                .onChange(of: playerVM.currentTime) { _, newTime in
                    guard isSynced,
                          autoScroll,
                          let transcript = playerVM.transcript,
                          let current = TranscriptService.getCurrentSegment(transcript, at: newTime),
                          current.id != lastScrolledSegmentId else { return }
                    lastScrolledSegmentId = current.id
                    if UIAccessibility.isReduceMotionEnabled {
                        proxy.scrollTo(current.id, anchor: .center)
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(current.id, anchor: .center)
                        }
                    }
                }
            }
        }
        .background(Color.appBackground)
    }

    private func isCurrentSegment(_ segment: TranscriptSegment) -> Bool {
        playerVM.currentTime >= segment.startTime && playerVM.currentTime < segment.endTime
    }

    private func scrollToCurrent(using proxy: ScrollViewProxy) {
        let episodeId = playerVM.currentEpisode?.id
        guard isSynced,
              scrolledForEpisodeId != episodeId,
              let transcript = playerVM.transcript,
              let current = TranscriptService.getCurrentSegment(transcript, at: playerVM.currentTime) else { return }
        scrolledForEpisodeId = episodeId
        lastScrolledSegmentId = current.id
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            proxy.scrollTo(current.id, anchor: .center)
        }
    }
}

#if DEBUG
#Preview("Med transkripsjon") {
    PreviewWrapper(player: .playing) {
        TranscriptPanel()
    }
}
#endif
