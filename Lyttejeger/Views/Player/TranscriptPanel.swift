import SwiftUI

struct TranscriptPanel: View {
    @Environment(AudioPlayerViewModel.self) private var playerVM
    @Environment(\.dismiss) private var dismiss
    @State private var autoScroll = true
    @State private var lastScrolledSegmentId: String?
    @State private var hasScrolledToInitial = false

    var body: some View {
        VStack(spacing: 0) {
            // Custom header
            HStack {
                Button {
                    autoScroll.toggle()
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: autoScroll ? "arrow.up.arrow.down" : "hand.draw")
                            .font(.system(size: 14))
                        Text(autoScroll ? "Auto" : "Manuell")
                            .font(.buttonText)
                    }
                    .foregroundStyle(Color.appAccent)
                }
                .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                .accessibilityLabel(autoScroll ? "Automatisk rulling på" : "Automatisk rulling av")

                Spacer()

                Button("Ferdig") { dismiss() }
                    .font(.buttonText)
                    .foregroundStyle(Color.appAccent)
                    .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.top, AppSpacing.sm)

            Divider()
                .background(Color.appBorder)
                .padding(.top, AppSpacing.sm)

            // Transcript content
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if let transcript = playerVM.transcript {
                            ForEach(transcript.segments) { segment in
                                let isCurrent = isCurrentSegment(segment)

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
                                                isCurrent
                                                    ? Color.appForeground
                                                    : Color.appMutedForeground.opacity(0.7)
                                            )
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, AppSpacing.lg)
                                .padding(.vertical, AppSpacing.md)
                                .background(isCurrent ? Color.appAccent.opacity(0.1) : Color.clear)
                                .id(segment.id)
                                .onTapGesture {
                                    playerVM.seek(to: segment.startTime)
                                }
                                .accessibilityLabel(segment.text)
                                .accessibilityHint("Trykk for å spole til dette tidspunktet")

                                // Divider between segments
                                if segment.id != transcript.segments.last?.id {
                                    Divider()
                                        .background(Color.appBorder.opacity(0.5))
                                        .padding(.leading, AppSpacing.lg + 3 + AppSpacing.sm)
                                }
                            }
                        } else {
                            Text("Ingen transkripsjon tilgjengelig")
                                .font(.bodyText)
                                .foregroundStyle(Color.appMutedForeground)
                                .padding(AppSpacing.lg)
                        }
                    }
                    .padding(.vertical, AppSpacing.sm)
                }
                .onAppear {
                    // Scroll to current segment when panel opens
                    guard !hasScrolledToInitial,
                          let transcript = playerVM.transcript,
                          let current = TranscriptService.getCurrentSegment(transcript, at: playerVM.currentTime) else { return }
                    hasScrolledToInitial = true
                    lastScrolledSegmentId = current.id
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(100))
                        proxy.scrollTo(current.id, anchor: .center)
                    }
                }
                .onChange(of: playerVM.currentTime) { _, newTime in
                    guard autoScroll,
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
}

#if DEBUG
#Preview("Med transkripsjon") {
    PreviewWrapper(player: .playing) {
        TranscriptPanel()
    }
}
#endif
