import SwiftUI

struct TranscriptPanel: View {
    @Environment(AudioPlayerViewModel.self) private var playerVM
    @Environment(\.dismiss) private var dismiss
    @State private var autoScroll = true
    @State private var lastScrolledSegmentId: String?

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppSpacing.sm) {
                        if let transcript = playerVM.transcript {
                            ForEach(transcript.segments) { segment in
                                VStack(alignment: .leading, spacing: 2) {
                                    if let speaker = segment.speaker {
                                        Text(speaker)
                                            .font(.badgeText)
                                            .foregroundStyle(Color.appAccent)
                                    }

                                    Text(segment.text)
                                        .font(.bodyText)
                                        .foregroundStyle(
                                            isCurrentSegment(segment)
                                                ? Color.appForeground
                                                : Color.appMutedForeground
                                        )
                                        .fontWeight(isCurrentSegment(segment) ? .medium : .regular)
                                }
                                .padding(.horizontal, AppSpacing.lg)
                                .padding(.vertical, AppSpacing.xs)
                                .background(
                                    isCurrentSegment(segment)
                                        ? Color.appAccent.opacity(0.08)
                                        : Color.clear
                                )
                                .clipShape(.rect(cornerRadius: AppRadius.sm))
                                .id(segment.id)
                                .onTapGesture {
                                    playerVM.seek(to: segment.startTime)
                                }
                                .accessibilityLabel(segment.text)
                                .accessibilityHint("Trykk for å spole til dette tidspunktet")
                            }
                        } else {
                            Text("Ingen transkripsjon tilgjengelig")
                                .font(.bodyText)
                                .foregroundStyle(Color.appMutedForeground)
                                .padding(AppSpacing.lg)
                        }
                    }
                    .padding(.vertical, AppSpacing.lg)
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
            .background(Color.appBackground)
            .navigationTitle("Transkripsjon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Toggle(isOn: $autoScroll) {
                        Image(systemName: autoScroll ? "arrow.up.arrow.down.circle.fill" : "arrow.up.arrow.down.circle")
                    }
                    .toggleStyle(.button)
                    .tint(Color.appAccent)
                    .accessibilityLabel(autoScroll ? "Automatisk rulling på" : "Automatisk rulling av")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ferdig") { dismiss() }
                        .font(.buttonText)
                        .foregroundStyle(Color.appAccent)
                }
            }
        }
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
