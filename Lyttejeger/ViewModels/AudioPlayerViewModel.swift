import Foundation
import SwiftData
import os

// MARK: - Last Played Info

struct LastPlayedInfo: Codable, Sendable {
    let episodeId: String
    let podcastId: String
    let title: String
    let audioUrl: String
    let duration: TimeInterval
    let imageUrl: String?
    let podcastTitle: String
    let podcastImage: String
    /// Carried so resuming from the home screen keeps the episode's chapters
    /// and transcript. Without these the rebuilt episode had neither, and
    /// "Fortsett å lytte" silently dropped both. Optional so records written
    /// by earlier versions still decode.
    var transcriptUrl: String?
    var chaptersUrl: String?

    func toEpisode() -> Episode {
        Episode(
            id: episodeId,
            podcastId: podcastId,
            title: title,
            description: "",
            audioUrl: audioUrl,
            duration: duration,
            publishedAt: "",
            imageUrl: imageUrl,
            transcriptUrl: transcriptUrl,
            chaptersUrl: chaptersUrl
        )
    }

    static func load() -> LastPlayedInfo? {
        guard let data = UserDefaults.standard.data(forKey: AppConstants.lastPlayedInfoKey) else { return nil }
        return try? JSONDecoder().decode(LastPlayedInfo.self, from: data)
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: AppConstants.lastPlayedInfoKey)
        }
    }
}

@Observable
@MainActor
final class AudioPlayerViewModel {
    private static let logger = Logger(subsystem: "com.Tazk.Lyttejeger", category: "AudioPlayerVM")
    private let audioService: any AudioPlaying
    private let chapterService: any ChapterFetching
    private let transcriptService: any TranscriptFetching
    private var modelContext: ModelContext?
    private(set) var queueVM: QueueViewModel?

    init(
        audioService: any AudioPlaying = AudioService.shared,
        chapterService: any ChapterFetching = ChapterService.shared,
        transcriptService: any TranscriptFetching = TranscriptService.shared
    ) {
        self.audioService = audioService
        self.chapterService = chapterService
        self.transcriptService = transcriptService
    }
    private var saveTask: Task<Void, Never>?
    private var seekTask: Task<Void, Never>?
    private var chapterTask: Task<Void, Never>?
    private var transcriptTask: Task<Void, Never>?
    private var autoAdvanceTask: Task<Void, Never>?
    private var fadeTask: Task<Void, Never>?
    private var isFadingOut = false

    // MARK: - State

    var currentEpisode: Episode? { audioService.currentEpisode }
    var podcastTitle: String? { audioService.currentPodcastTitle }
    var podcastImage: String? { audioService.currentPodcastImage }
    var isPlaying: Bool { audioService.isPlaying }
    var currentTime: TimeInterval { audioService.currentTime }
    var duration: TimeInterval { audioService.duration }
    var isLoading: Bool { audioService.isLoading }
    var hasError: Bool { audioService.hasError }
    var playbackSpeed: Float { audioService.playbackSpeed }

    var isExpanded = false
    var pendingPodcastRoute: PodcastRoute?

    // Sleep timer
    var sleepTimerMinutes: Int = 0
    var sleepTimerEndTime: Date?
    var sleepTimerRemaining: TimeInterval = 0

    // Chapters
    var chapters: [Chapter] = []
    /// True when the episode declares chapters but they could not be fetched,
    /// so the UI can say so instead of pretending there are none.
    var chaptersFailed = false

    /// Derived rather than stored. It used to be refreshed from the position
    /// save timer, which left the highlight and the player's chapter label up
    /// to `playbackSaveInterval` seconds behind — most visibly right after
    /// tapping a chapter to seek to it.
    var currentChapter: Chapter? {
        ChapterService.getCurrentChapter(chapters, at: currentTime)
    }

    // Transcript
    var transcript: Transcript?
    /// Same distinction as `chaptersFailed`, for the transcript.
    var transcriptFailed = false

    func setup(_ context: ModelContext, queueVM: QueueViewModel? = nil) {
        self.modelContext = context
        self.queueVM = queueVM
        audioService.onRemotePlay = { [weak self] in
            self?.restorePositionIfNeeded()
        }
    }

    // MARK: - Smart resume

    /// Where playback should pick up, given where it stopped and when.
    ///
    /// After a long pause the listener has lost the thread, so playback starts
    /// a little earlier and hands back the last few seconds of context instead
    /// of dropping them mid-sentence. Shared by all three resume paths — the
    /// rule used to be written out at each of them, and they had already
    /// drifted apart.
    static func smartResumePosition(_ position: TimeInterval, pausedSince: Date) -> TimeInterval {
        guard Date().timeIntervalSince(pausedSince) > AppConstants.smartResumeThreshold else {
            return position
        }
        return max(0, position - AppConstants.smartResumeRewind)
    }

    // MARK: - Playback

    func play(episode: Episode, podcastTitle: String?, podcastImage: String?) {
        // Cancel any pending auto-advance or fade
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
        fadeTask?.cancel()
        fadeTask = nil
        if isFadingOut {
            audioService.setVolume(1.0)
            isFadingOut = false
        }

        // Load per-podcast speed (default to 1.0x if no preference saved)
        let podcastSpeed = loadSpeedForPodcast(episode.podcastId) ?? 1.0
        audioService.setSpeed(podcastSpeed)

        // Load saved position
        var savedPosition: TimeInterval? = nil
        var positionUpdatedAt: Date?
        if let modelContext {
            let episodeId = episode.id
            let descriptor = FetchDescriptor<PlaybackPosition>(predicate: #Predicate { $0.episodeId == episodeId })
            if let saved = try? modelContext.fetch(descriptor).first, !saved.completed {
                savedPosition = saved.position
                positionUpdatedAt = saved.updatedAt
            }
        }

        if let position = savedPosition, let updatedAt = positionUpdatedAt {
            savedPosition = Self.smartResumePosition(position, pausedSince: updatedAt)
        }

        audioService.play(episode: episode, podcastTitle: podcastTitle, podcastImage: podcastImage)

        // Save last-played info for Home screen
        LastPlayedInfo(
            episodeId: episode.id,
            podcastId: episode.podcastId,
            title: episode.title,
            audioUrl: episode.audioUrl,
            duration: episode.duration,
            imageUrl: episode.imageUrl,
            podcastTitle: podcastTitle ?? "",
            podcastImage: podcastImage ?? "",
            transcriptUrl: episode.transcriptUrl,
            chaptersUrl: episode.chaptersUrl
        ).save()

        // Cancel any in-flight Tasks from a previous episode
        seekTask?.cancel()
        chapterTask?.cancel()
        transcriptTask?.cancel()

        // Seek to saved position after player is ready
        if let savedPosition {
            seekTask = Task { @MainActor in
                // Wait for player to be ready (check duration is valid)
                for _ in 0..<AppConstants.statusPollingMaxAttempts {
                    guard !Task.isCancelled else { return }
                    if audioService.duration > 0 {
                        audioService.seek(to: savedPosition)
                        break
                    }
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }
        }

        startSaveTimer()

        // Load chapters and transcript
        loadChapters(for: episode)
        loadTranscript(for: episode)
    }

    // MARK: - Chapters & Transcript

    /// Clearing before the fetch matters: without it the previous episode's
    /// chapters stayed on screen for the whole round trip. The cancellation
    /// check on the success path matters for the same reason — a fetch that
    /// completes after its episode was switched away from would otherwise
    /// publish the old episode's chapters onto the new one.
    func loadChapters(for episode: Episode) {
        chapterTask?.cancel()
        chapters = []
        chaptersFailed = false
        guard let chaptersUrl = episode.chaptersUrl else { return }

        chapterTask = Task { @MainActor in
            do {
                let fetched = try await chapterService.fetchChapters(from: chaptersUrl)
                guard !Task.isCancelled else { return }
                chapters = fetched
            } catch {
                guard !Task.isCancelled else { return }
                chapters = []
                chaptersFailed = true
            }
        }
    }

    func loadTranscript(for episode: Episode) {
        transcriptTask?.cancel()
        transcript = nil
        transcriptFailed = false
        guard let transcriptUrl = episode.transcriptUrl else { return }

        transcriptTask = Task { @MainActor in
            do {
                let fetched = try await transcriptService.fetchTranscript(from: transcriptUrl)
                guard !Task.isCancelled else { return }
                transcript = fetched
            } catch {
                guard !Task.isCancelled else { return }
                transcript = nil
                transcriptFailed = true
            }
        }
    }

    /// Re-runs a failed chapter fetch for the episode that is playing.
    func retryChapters() {
        guard let episode = currentEpisode else { return }
        loadChapters(for: episode)
    }

    /// Re-runs a failed transcript fetch for the episode that is playing.
    func retryTranscript() {
        guard let episode = currentEpisode else { return }
        loadTranscript(for: episode)
    }

    func stop() {
        savePosition()
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
        fadeTask?.cancel()
        fadeTask = nil
        saveTask?.cancel()
        saveTask = nil
        seekTask?.cancel()
        seekTask = nil
        chapterTask?.cancel()
        chapterTask = nil
        transcriptTask?.cancel()
        transcriptTask = nil
        if isFadingOut {
            audioService.setVolume(1.0)
            isFadingOut = false
        }
        isExpanded = false
        chapters = []
        chaptersFailed = false
        transcript = nil
        transcriptFailed = false
        sleepTimerMinutes = 0
        sleepTimerEndTime = nil
        sleepTimerRemaining = 0
        audioService.stop()
    }

    func togglePlayPause() {
        if !isPlaying, let pausedAt = audioService.pausedAt {
            let target = Self.smartResumePosition(currentTime, pausedSince: pausedAt)
            if target < currentTime {
                audioService.seek(to: target)
            }
        }
        audioService.togglePlayPause()
    }

    func skipBackward() {
        audioService.skipBackward()
    }

    func skipForward() {
        audioService.skipForward()
    }

    func seek(to time: TimeInterval) {
        audioService.seek(to: time)
    }

    func cycleSpeed() {
        let speeds = AppConstants.playbackSpeeds
        let currentIndex = speeds.firstIndex(of: playbackSpeed) ?? 2
        let nextIndex = (currentIndex + 1) % speeds.count
        let newSpeed = speeds[nextIndex]
        audioService.setSpeed(newSpeed)
        if let podcastId = currentEpisode?.podcastId {
            saveSpeedForPodcast(podcastId, speed: newSpeed)
        }
    }

    func seekToChapter(_ chapter: Chapter) {
        audioService.seek(to: chapter.startTime)
    }

    // MARK: - Sleep Timer

    func setSleepTimer(_ minutes: Int) {
        sleepTimerMinutes = minutes
        if minutes > 0 {
            sleepTimerEndTime = Date().addingTimeInterval(TimeInterval(minutes * 60))
        } else {
            sleepTimerEndTime = nil
        }
    }

    func checkSleepTimer() {
        guard sleepTimerMinutes != 0 else { return }

        if sleepTimerMinutes == -1 {
            // End of episode — start fade during last 30 seconds
            let remaining = duration - currentTime
            if duration > 0 && remaining <= AppConstants.sleepFadeDuration && remaining > 0 {
                startSleepFade()
            } else if duration > 0 && currentTime >= duration - 1 {
                completeSleepFade()
            }
        } else if let endTime = sleepTimerEndTime {
            sleepTimerRemaining = endTime.timeIntervalSince(Date())
            if sleepTimerRemaining <= 0 {
                completeSleepFade()
            } else if sleepTimerRemaining <= AppConstants.sleepFadeDuration {
                startSleepFade()
            }
        }
    }

    private func startSleepFade() {
        guard !isFadingOut else { return }
        isFadingOut = true
        fadeTask?.cancel()
        fadeTask = Task { @MainActor in
            let steps = Int(AppConstants.sleepFadeDuration)
            for step in 1...steps {
                guard !Task.isCancelled else { return }
                let volume = Float(steps - step) / Float(steps)
                audioService.setVolume(max(0, volume))
                try? await Task.sleep(for: .seconds(1))
            }
            guard !Task.isCancelled else { return }
            completeSleepFade()
        }
    }

    private func completeSleepFade() {
        fadeTask?.cancel()
        fadeTask = nil
        audioService.pause()
        audioService.setVolume(1.0)
        isFadingOut = false
        sleepTimerMinutes = 0
        sleepTimerEndTime = nil
        sleepTimerRemaining = 0
    }

    // MARK: - Position Restore (Bluetooth/Tesla workaround)

    /// Some car head units (notably Tesla) reset playback to the beginning when
    /// sending an AVRCP play command via Bluetooth. This method detects that
    /// scenario and seeks back to the saved position.
    private func restorePositionIfNeeded() {
        guard let modelContext, let episode = currentEpisode else { return }
        guard currentTime < 3.0 else { return }

        let episodeId = episode.id
        let descriptor = FetchDescriptor<PlaybackPosition>(predicate: #Predicate { $0.episodeId == episodeId })
        guard let saved = try? modelContext.fetch(descriptor).first,
              !saved.completed,
              saved.position > 30.0 else { return }

        // Remote play restarted the episode from the top, so this is a resume
        // like any other and earns the same rewind.
        audioService.seek(to: Self.smartResumePosition(saved.position, pausedSince: saved.updatedAt))
    }

    // MARK: - Position Saving

    private func startSaveTimer() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(AppConstants.playbackSaveInterval))
                guard !Task.isCancelled else { break }
                savePosition()
                checkSleepTimer()
                checkAutoAdvance()
            }
        }
    }

    func savePosition() {
        guard let modelContext, let episode = currentEpisode else { return }
        let time = currentTime
        let dur = duration
        guard dur > 0 else { return }

        let completed = time / dur > AppConstants.completionThreshold
        let episodeId = episode.id

        let descriptor = FetchDescriptor<PlaybackPosition>(predicate: #Predicate { $0.episodeId == episodeId })

        if let existing = try? modelContext.fetch(descriptor).first {
            // The save timer keeps ticking while playback is paused, so this
            // runs every few seconds with a position that has not moved.
            // Writing anyway refreshed `updatedAt`, which is exactly what smart
            // resume measures the pause from — so resuming a long-paused
            // episode never rewound. It also kept the store churning for as
            // long as anything stayed paused.
            guard existing.position != time
                || existing.duration != dur
                || existing.completed != completed else { return }
            existing.position = time
            existing.duration = dur
            existing.updatedAt = Date()
            existing.completed = completed
        } else {
            let pos = PlaybackPosition(
                episodeId: episodeId,
                position: time,
                duration: dur,
                completed: completed
            )
            modelContext.insert(pos)
        }

        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Failed to save playback position: \(error)")
        }
    }

    // MARK: - Auto-Advance

    func checkAutoAdvance() {
        guard !isPlaying,
              duration > 0,
              currentTime >= duration - 1,
              sleepTimerMinutes == 0,
              autoAdvanceTask == nil else { return }

        guard let queueVM, !queueVM.items.isEmpty else { return }

        autoAdvanceTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(AppConstants.autoAdvanceDelay))
            guard !Task.isCancelled else { return }
            guard let next = queueVM.nextAfterPlaying(episodeId: self.currentEpisode?.id) else { return }
            self.play(episode: next.episode, podcastTitle: next.podcastTitle, podcastImage: next.podcastImage)
            Self.logger.info("Auto-advanced to: \(next.episode.title, privacy: .private)")
        }
    }

    // MARK: - Per-Podcast Speed

    private func loadSpeedForPodcast(_ podcastId: String) -> Float? {
        guard let data = UserDefaults.standard.data(forKey: AppConstants.podcastSpeedPrefsKey),
              let prefs = try? JSONDecoder().decode([String: Float].self, from: data) else {
            return nil
        }
        return prefs[podcastId]
    }

    private func saveSpeedForPodcast(_ podcastId: String, speed: Float) {
        var prefs: [String: Float] = [:]
        if let data = UserDefaults.standard.data(forKey: AppConstants.podcastSpeedPrefsKey),
           let existing = try? JSONDecoder().decode([String: Float].self, from: data) {
            prefs = existing
        }
        if speed == 1.0 {
            prefs.removeValue(forKey: podcastId)
        } else {
            prefs[podcastId] = speed
        }
        if let data = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(data, forKey: AppConstants.podcastSpeedPrefsKey)
        }
    }
}
