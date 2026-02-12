import SwiftUI

struct PlayerControls: View {
    @Environment(AudioPlayerViewModel.self) private var playerVM
    @State private var showSleepTimer = false
    @State private var isSeeking = false
    @State private var seekPosition: TimeInterval = 0
    @State private var skipOverlay: String?

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
                        set: { seekPosition = $0 }
                    ),
                    in: 0...max(playerVM.duration, 0.1),
                    onEditingChanged: { editing in
                        isSeeking = editing
                        if !editing {
                            playerVM.seek(to: seekPosition)
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

            // Main controls
            ZStack {
                HStack(spacing: AppSpacing.xxl) {
                    // Speed
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        playerVM.cycleSpeed()
                    } label: {
                        Text(String(format: "%.2gx", playerVM.playbackSpeed))
                            .font(.speedText)
                            .foregroundStyle(Color.appMutedForeground)
                            .frame(width: 44)
                    }
                    .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                    .accessibilityLabel("Hastighet \(String(format: "%.2g", playerVM.playbackSpeed)) ganger")
                    .accessibilityHint("Trykk for å endre avspillingshastighet")

                    // Skip back
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        playerVM.skipBackward()
                        showSkipOverlay("-10s")
                    } label: {
                        Image(systemName: "gobackward.10")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.appForeground)
                    }
                    .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                    .accessibilityLabel("Spol 10 sekunder tilbake")

                    // Play/Pause
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        playerVM.togglePlayPause()
                    } label: {
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
                    .accessibilityLabel(playerVM.isPlaying ? "Pause" : "Spill av")

                    // Skip forward
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        playerVM.skipForward()
                        showSkipOverlay("+30s")
                    } label: {
                        Image(systemName: "goforward.30")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.appForeground)
                    }
                    .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                    .accessibilityLabel("Spol 30 sekunder frem")

                    // Sleep timer
                    Button {
                        showSleepTimer = true
                    } label: {
                        VStack(spacing: 1) {
                            Image(systemName: playerVM.sleepTimerMinutes != 0 ? "moon.fill" : "moon")
                                .font(.system(size: 20))
                                .foregroundStyle(playerVM.sleepTimerMinutes != 0 ? Color.appAccent : Color.appMutedForeground)

                            if let label = sleepTimerLabel {
                                Text(label)
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Color.appAccent)
                            }
                        }
                    }
                    .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                    .accessibilityLabel(playerVM.sleepTimerMinutes != 0 ? "Søvntimer aktiv" : "Søvntimer")
                    .accessibilityHint("Trykk for å stille søvntimer")
                }

                // Skip overlay
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
            }

            // Chapter info
            if let chapter = playerVM.currentChapter {
                Text(chapter.title)
                    .font(.smallText)
                    .foregroundStyle(Color.appAccent)
                    .lineLimit(1)
            }
        }
        .confirmationDialog("Søvntimer", isPresented: $showSleepTimer) {
            ForEach(AppConstants.sleepTimerOptions, id: \.value) { option in
                Button(option.label) {
                    playerVM.setSleepTimer(option.value)
                }
            }
        }
    }

    private func showSkipOverlay(_ text: String) {
        withAnimation(.easeOut(duration: 0.15)) { skipOverlay = text }
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            withAnimation(.easeOut(duration: 0.2)) { skipOverlay = nil }
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
