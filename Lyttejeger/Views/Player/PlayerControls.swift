import SwiftUI

struct PlayerControls: View {
    @Environment(AudioPlayerViewModel.self) private var playerVM
    @State private var showSpeedPicker = false
    @State private var showSleepTimer = false
    @State private var isSeeking = false
    @State private var seekPosition: TimeInterval = 0

    private var displayTime: TimeInterval {
        isSeeking ? seekPosition : playerVM.currentTime
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
                    Image(systemName: playerVM.sleepTimerMinutes != 0 ? "moon.fill" : "moon")
                        .font(.system(size: 20))
                        .foregroundStyle(playerVM.sleepTimerMinutes != 0 ? Color.appAccent : Color.appMutedForeground)
                }
                .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                .accessibilityLabel(playerVM.sleepTimerMinutes != 0 ? "Søvntimer aktiv" : "Søvntimer")
                .accessibilityHint("Trykk for å stille søvntimer")
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
}

#if DEBUG
#Preview("Med fremdrift") {
    PreviewWrapper(player: .playing) {
        PlayerControls()
            .padding()
    }
}
#endif
