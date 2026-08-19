import SwiftUI

struct PlayerControls: View {
    @Environment(AudioPlayerViewModel.self) private var playerVM
    @State private var showSleepTimer = false
    @State private var isSeeking = false
    @State private var seekPosition: TimeInterval = 0
    /// When the slider was last moved. Used to detect that a drag has ended
    /// even when SwiftUI never delivers the end-of-drag callback.
    @State private var lastSliderInteraction = Date.distantPast
    @State private var skipOverlay: String?
    @State private var skipOverlayTask: Task<Void, Never>?

    private var displayTime: TimeInterval {
        isSeeking ? seekPosition : playerVM.currentTime
    }

    private var sleepTimerLabel: String? {
        guard playerVM.sleepTimerMinutes != 0 else { return nil }
        if playerVM.sleepTimerMinutes == -1 { return "Ep. slutt" }
        let remaining = playerVM.sleepTimerRemaining
        if remaining > 0 {
            let mins = Int(remaining) / 60
            return "\(mins) min"
        }
        return nil
    }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // Progress slider
            VStack(spacing: AppSpacing.xs) {
                Slider(
                    value: Binding(
                        get: { displayTime },
                        set: { newValue in
                            // isSeeking is set here as well as in
                            // onEditingChanged: the begin callback is not
                            // guaranteed either, and the thumb must still
                            // follow the finger without it.
                            seekPosition = newValue
                            lastSliderInteraction = Date()
                            isSeeking = true
                        }
                    ),
                    in: 0...max(playerVM.duration, 0.1),
                    onEditingChanged: { editing in
                        if editing {
                            // Seed from the live position: seekPosition
                            // otherwise still holds the previous drag's value
                            // (0 the first time), so releasing without moving
                            // would jump to the start of the episode.
                            seekPosition = playerVM.currentTime
                            lastSliderInteraction = Date()
                            isSeeking = true
                        } else {
                            commitSeek()
                        }
                    }
                )
                .tint(Color.appAccent)
                .accessibilityLabel("Fremdrift")
                .accessibilityValue("\(formatTime(displayTime)) av \(formatTime(playerVM.duration))")

                HStack {
                    Text(formatTime(displayTime))
                        .font(.playerTime)
                        .foregroundStyle(Color.appMutedForeground)
                    Spacer()
                    Text("-\(formatTime(max(0, playerVM.duration - displayTime)))")
                        .font(.playerTime)
                        .foregroundStyle(Color.appMutedForeground)
                }
            }

            // Main controls. xl rather than xxl: five fixed-width controls plus
            // xxl spacing exceeded the usable width of a 375pt screen.
            HStack(spacing: AppSpacing.xl) {
                // Speed
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    playerVM.cycleSpeed()
                } label: {
                    Text(String(format: "%.2gx", playerVM.playbackSpeed))
                        .font(.speedText)
                        .foregroundStyle(Color.appMutedForeground)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: AppSize.touchTarget)
                        .frame(minHeight: AppSize.touchTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Hastighet \(String(format: "%.2g", playerVM.playbackSpeed)) ganger")
                .accessibilityHint("Trykk for å endre avspillingshastighet")

                // Skip back
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    playerVM.skipBackward()
                    showSkipOverlay("-10s")
                } label: {
                    Image(systemName: "gobackward.10")
                        .font(.system(.title))
                        .foregroundStyle(Color.appForeground)
                        .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Spol 10 sekunder tilbake")

                // Play/Pause
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    playerVM.togglePlayPause()
                } label: {
                    Group {
                        if playerVM.isLoading {
                            ProgressView()
                                .tint(Color.appAccent)
                                .frame(width: AppSize.playerMainButton, height: AppSize.playerMainButton)
                        } else {
                            Image(systemName: playerVM.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: AppSize.playerMainButton))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.appAccent, Color.appAccentHover],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    }
                    .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                    .contentShape(Rectangle())
                }
                .disabled(playerVM.isLoading)
                .accessibilityLabel(
                    playerVM.isLoading ? "Laster episoden"
                        : playerVM.isPlaying ? "Pause" : "Spill av"
                )

                // Skip forward
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    playerVM.skipForward()
                    showSkipOverlay("+30s")
                } label: {
                    Image(systemName: "goforward.30")
                        .font(.system(.title))
                        .foregroundStyle(Color.appForeground)
                        .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Spol 30 sekunder frem")

                // Sleep timer
                Button {
                    showSleepTimer = true
                } label: {
                    VStack(spacing: 1) {
                        Image(systemName: playerVM.sleepTimerMinutes != 0 ? "moon.fill" : "moon")
                            .font(.system(.title3))
                            .foregroundStyle(playerVM.sleepTimerMinutes != 0 ? Color.appAccent : Color.appMutedForeground)

                        if let label = sleepTimerLabel {
                            Text(label)
                                .font(.badgeText)
                                .foregroundStyle(Color.appAccent)
                        }
                    }
                    .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel(playerVM.sleepTimerMinutes != 0 ? "Søvntimer aktiv" : "Søvntimer")
                .accessibilityHint("Trykk for å stille søvntimer")
            }

            // Skip confirmation — below controls, separate from button layout
            if let overlay = skipOverlay {
                Text(overlay)
                    .font(.caption2Text)
                    .foregroundStyle(Color.appAccent)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.xs)
                    .background(Color.appAccent.opacity(0.12))
                    .clipShape(.rect(cornerRadius: AppRadius.sm))
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            // Chapter info
            if let chapter = playerVM.currentChapter {
                Text(chapter.title)
                    .font(.smallText)
                    .foregroundStyle(Color.appAccent)
                    .lineLimit(1)
            }
        }
        .onChange(of: playerVM.currentTime) { _, _ in
            // SwiftUI does not guarantee the end-of-drag callback: when another
            // gesture recogniser takes over the touch it is simply never
            // delivered. Relying on it left the position frozen on screen while
            // audio kept playing. If the slider has not moved for a moment, the
            // drag is over — commit it and hand the display back to the player.
            if isSeeking, Date().timeIntervalSince(lastSliderInteraction) > 1.5 {
                commitSeek()
            }
        }
        .onChange(of: playerVM.currentEpisode?.id) { _, _ in
            isSeeking = false
        }
        .confirmationDialog("Søvntimer", isPresented: $showSleepTimer, titleVisibility: .visible) {
            ForEach(AppConstants.sleepTimerOptions, id: \.value) { option in
                Button(option.label) {
                    playerVM.setSleepTimer(option.value)
                }
            }
        } message: {
            Text("Avspillingen stopper automatisk etter valgt tid.")
        }
    }

    /// Ends a scrub: hand the display back to the player and seek once.
    private func commitSeek() {
        guard isSeeking else { return }
        isSeeking = false
        playerVM.seek(to: seekPosition)
    }

    private func showSkipOverlay(_ text: String) {
        skipOverlayTask?.cancel()
        if UIAccessibility.isReduceMotionEnabled {
            skipOverlay = text
            skipOverlayTask = Task {
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }
                skipOverlay = nil
            }
        } else {
            withAnimation(.easeOut(duration: 0.15)) { skipOverlay = text }
            skipOverlayTask = Task {
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.2)) { skipOverlay = nil }
            }
        }
    }
}

#if DEBUG
#Preview("Med fremdrift") {
    PreviewWrapper(player: .playing) {
        PlayerControls()
            .padding()
    }
}
#endif
