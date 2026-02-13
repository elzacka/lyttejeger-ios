import Foundation
import SwiftData

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
        guard let data = UserDefaults.standard.data(forKey: "lastPlayedInfo") else { return nil }
        return try? JSONDecoder().decode(LastPlayedInfo.self, from: data)
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "lastPlayedInfo")
        }
    }
}

@Observable
@MainActor
final class AudioPlayerViewModel {
    private let audioService = AudioService.shared
    private var modelContext: ModelContext?
    private var saveTask: Task<Void, Never>?

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

    func setup(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Playback

    func play(episode: Episode, podcastTitle: String?, podcastImage: String?) {
        // Load saved position
        var savedPosition: TimeInterval? = nil
        if let modelContext {
            let episodeId = episode.id
            let descriptor = FetchDescriptor<PlaybackPosition>(predicate: #Predicate { $0.episodeId == episodeId })
            if let saved = try? modelContext.fetch(descriptor).first, !saved.completed {
                savedPosition = saved.position
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

        // Seek to saved position after player is ready
        if let savedPosition {
            Task { @MainActor in
                // Wait for player to be ready (check duration is valid)
                for _ in 0..<20 { // Try for up to 2 seconds
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
        Task { @MainActor in
            if let chaptersUrl = episode.chaptersUrl {
                chapters = await ChapterService.shared.fetchChapters(from: chaptersUrl)
            } else {
                chapters = []
            }
        }
        Task { @MainActor in
            if let transcriptUrl = episode.transcriptUrl {
                transcript = await TranscriptService.shared.fetchTranscript(from: transcriptUrl)
            } else {
                transcript = nil
            }
        }
    }

    func stop() {
        savePosition()
        saveTask?.cancel()
        saveTask = nil
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
        audioService.setSpeed(speeds[nextIndex])
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
            // End of episode
            if duration > 0 && currentTime >= duration - 1 {
                audioService.togglePlayPause()
                sleepTimerMinutes = 0
            }
        } else if let endTime = sleepTimerEndTime {
            sleepTimerRemaining = endTime.timeIntervalSince(Date())
            if sleepTimerRemaining <= 0 {
                audioService.togglePlayPause()
                sleepTimerMinutes = 0
                sleepTimerEndTime = nil
            }
        }
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
            }
        }
    }

    func savePosition() {
        guard let modelContext, let episode = currentEpisode else { return }
        let time = currentTime
        let dur = duration
        guard dur > 0 else { return }

        let completed = time / dur > 0.9
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

        try? modelContext.save()
    }
}
