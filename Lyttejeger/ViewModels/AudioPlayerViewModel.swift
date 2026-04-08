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

    func toEpisode() -> Episode {
        Episode(
            id: episodeId,
            podcastId: podcastId,
            title: title,
            description: "",
            audioUrl: audioUrl,
            duration: duration,
            publishedAt: "",
            imageUrl: imageUrl
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
    var currentChapter: Chapter?

    // Transcript
    var transcript: Transcript?

    func setup(_ context: ModelContext, queueVM: QueueViewModel? = nil) {
        self.modelContext = context
        self.queueVM = queueVM
        audioService.onRemotePlay = { [weak self] in
            self?.restorePositionIfNeeded()
        }
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

        // Smart resume: rewind 10s if paused for 5+ minutes
        if let position = savedPosition, let updatedAt = positionUpdatedAt {
            let pauseDuration = Date().timeIntervalSince(updatedAt)
            if pauseDuration > AppConstants.smartResumeThreshold {
                savedPosition = max(0, position - AppConstants.smartResumeRewind)
            }
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
            podcastImage: podcastImage ?? ""
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
        chapterTask = Task { @MainActor in
            if let chaptersUrl = episode.chaptersUrl {
                chapters = await chapterService.fetchChapters(from: chaptersUrl)
            } else {
                chapters = []
            }
        }
        transcriptTask = Task { @MainActor in
            if let transcriptUrl = episode.transcriptUrl {
                transcript = await transcriptService.fetchTranscript(from: transcriptUrl)
            } else {
                transcript = nil
            }
        }
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
        currentChapter = nil
        transcript = nil
        sleepTimerMinutes = 0
        sleepTimerEndTime = nil
        sleepTimerRemaining = 0
        audioService.stop()
    }

    func togglePlayPause() {
        // Smart resume: rewind 10s if paused for 5+ minutes
        if !isPlaying, let pausedAt = audioService.pausedAt {
            let pauseDuration = Date().timeIntervalSince(pausedAt)
            if pauseDuration > AppConstants.smartResumeThreshold && currentTime > AppConstants.smartResumeRewind {
                audioService.seek(to: currentTime - AppConstants.smartResumeRewind)
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

    // MARK: - Chapter tracking

    func updateCurrentChapter() {
        guard !chapters.isEmpty else {
            currentChapter = nil
            return
        }
        currentChapter = ChapterService.getCurrentChapter(chapters, at: currentTime)
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

        let position = saved.position
        audioService.seek(to: position)
    }

    // MARK: - Position Saving

    private func startSaveTimer() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(AppConstants.playbackSaveInterval))
                guard !Task.isCancelled else { break }
                savePosition()
                updateCurrentChapter()
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
            guard let next = queueVM.popFirst() else { return }
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
