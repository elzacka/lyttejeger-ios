import Foundation
import AVFoundation
import MediaPlayer
import UIKit
import os

private let audioLogger = Logger(subsystem: "com.Tazk.Lyttejeger", category: "AudioService")

@Observable
@MainActor
final class AudioService: AudioPlaying {
    static let shared = AudioService()

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var statusCheckTask: Task<Void, Never>?
    private var endOfPlaybackObserver: (any NSObjectProtocol)?
    private var interruptionObserver: (any NSObjectProtocol)?
    private var routeChangeObserver: (any NSObjectProtocol)?

    // MARK: - State

    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var isLoading = false
    var hasError = false
    var playbackSpeed: Float = 1.0
    var pausedAt: Date?

    private var wasPlayingBeforeInterruption = false
    private var artworkCache: [String: MPMediaItemArtwork] = [:]
    private var artworkFetchingUrl: String?

    // MARK: - Current Episode

    var currentEpisode: Episode?
    var currentPodcastTitle: String?
    var currentPodcastImage: String?

    /// Called after a remote play command (Bluetooth/AVRCP) resumes playback.
    /// Used by AudioPlayerViewModel to restore saved position when a car head unit
    /// (e.g. Tesla) resets playback to the beginning.
    var onRemotePlay: (() -> Void)?

    private init() {
        setupAudioSession()
        setupInterruptionHandling()
        setupRouteChangeHandling()
        Task.detached { [weak self] in
            self?.setupRemoteCommands()
        }
    }

    // MARK: - Audio Session

    private nonisolated func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            audioLogger.error("Audio session setup failed: \(error)")
        }
    }

    // MARK: - Interruption & Route Change Handling

    private func setupInterruptionHandling() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            // Extract values from notification before crossing actor boundary
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            let shouldResume: Bool = {
                guard type == .ended,
                      let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return false }
                return AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume)
            }()

            Task { @MainActor in
                guard let self else { return }
                switch type {
                case .began:
                    // Remember state so .ended only resumes what the
                    // interruption itself paused — not a manual pause
                    self.wasPlayingBeforeInterruption = self.isPlaying
                    if self.isPlaying {
                        self.player?.pause()
                        self.isPlaying = false
                        self.updateNowPlaying()
                        audioLogger.info("Playback paused due to interruption")
                    }
                case .ended:
                    if shouldResume && self.wasPlayingBeforeInterruption {
                        self.player?.rate = self.playbackSpeed
                        self.isPlaying = true
                        self.updateNowPlaying()
                        audioLogger.info("Playback resumed after interruption")
                    }
                    self.wasPlayingBeforeInterruption = false
                @unknown default:
                    break
                }
            }
        }
    }

    private func setupRouteChangeHandling() {
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            // Extract reason before crossing actor boundary
            guard let userInfo = notification.userInfo,
                  let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
                  reason == .oldDeviceUnavailable else { return }

            Task { @MainActor in
                guard let self, self.isPlaying else { return }
                self.player?.pause()
                self.isPlaying = false
                self.updateNowPlaying()
                audioLogger.info("Playback paused: audio device disconnected")
            }
        }
    }

    // MARK: - Playback Control

    func play(episode: Episode, podcastTitle: String?, podcastImage: String?) {
        guard let url = URL(string: episode.audioUrl) else {
            hasError = true
            return
        }

        // Clean up previous
        stop()

        currentEpisode = episode
        currentPodcastTitle = podcastTitle
        currentPodcastImage = podcastImage
        isLoading = true
        hasError = false
        pausedAt = nil

        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.automaticallyWaitsToMinimizeStalling = true

        // Poll for readyToPlay entirely on MainActor.
        // KVO on AVPlayerItem.status fires on background threads and the KVO
        // machinery itself reads .status off-main, triggering iOS 26's
        // _dispatch_assert_queue_fail. Polling avoids KVO entirely.
        statusCheckTask = Task { @MainActor in
            for _ in 0..<AppConstants.statusPollingMaxAttempts {
                guard !Task.isCancelled else { return }
                guard let currentItem = self.player?.currentItem else { return }
                switch currentItem.status {
                case .readyToPlay:
                    self.handlePlayerStatusChange()
                    return
                case .failed:
                    self.isLoading = false
                    self.hasError = true
                    return
                default:
                    break
                }
                try? await Task.sleep(for: .milliseconds(AppConstants.statusPollingIntervalMs))
            }
            // Timeout after 30 seconds
            self.isLoading = false
            self.hasError = true
        }

        // Time observer (queue: .main ensures callback is on main dispatch queue)
        // Use Task { @MainActor in } (safe scheduling) instead of
        // MainActor.assumeIsolated (which calls dispatch_assert_queue and crashes
        // if the callback isn't on the exact main dispatch queue).
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                let seconds = time.seconds
                if seconds.isFinite {
                    self.currentTime = seconds
                }
                let actuallyPlaying = self.player?.timeControlStatus == .playing
                if self.isPlaying != actuallyPlaying {
                    self.isPlaying = actuallyPlaying
                }
            }
        }

        // End of playback notification
        endOfPlaybackObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isPlaying = false
                self.currentTime = self.duration
            }
        }
    }

    private func handlePlayerStatusChange() {
        guard let currentItem = player?.currentItem else { return }
        switch currentItem.status {
        case .readyToPlay:
            isLoading = false
            duration = currentItem.duration.seconds.isFinite ? currentItem.duration.seconds : 0
            player?.rate = playbackSpeed
            isPlaying = true
            updateNowPlaying()
        case .failed:
            isLoading = false
            hasError = true
        default:
            break
        }
    }

    func togglePlayPause() {
        guard let player, !hasError else { return }

        if isPlaying {
            player.pause()
            isPlaying = false
            pausedAt = Date()
        } else {
            // Setting rate to non-zero resumes at the correct speed (no need for play() + rate)
            player.rate = playbackSpeed
            isPlaying = true
            pausedAt = nil
        }
        updateNowPlaying()
    }

    func pause() {
        guard let player, isPlaying else { return }
        player.pause()
        isPlaying = false
        pausedAt = Date()
        updateNowPlaying()
    }

    func setVolume(_ volume: Float) {
        player?.volume = max(0, min(1, volume))
    }

    func seek(to time: TimeInterval) {
        guard player != nil else { return }
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            guard finished else { return }
            Task { @MainActor in
                self?.updateNowPlaying()
            }
        }
    }

    func skipBackward() {
        let newTime = max(0, currentTime - AppConstants.skipBackward)
        seek(to: newTime)
    }

    func skipForward() {
        let newTime = min(duration, currentTime + AppConstants.skipForward)
        seek(to: newTime)
    }

    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        if isPlaying {
            player?.rate = speed
        }
        updateNowPlaying()
    }

    func stop() {
        if let endOfPlaybackObserver {
            NotificationCenter.default.removeObserver(endOfPlaybackObserver)
        }
        endOfPlaybackObserver = nil
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        statusCheckTask?.cancel()
        statusCheckTask = nil
        player?.pause()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        isLoading = false
        hasError = false
        pausedAt = nil
        currentEpisode = nil
        currentPodcastTitle = nil
        currentPodcastImage = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Now Playing

    private func updateNowPlaying() {
        guard currentEpisode != nil else { return }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentEpisode?.title ?? "",
            MPMediaItemPropertyArtist: currentPodcastTitle ?? "",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(playbackSpeed) : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: Double(playbackSpeed)
        ]

        if let imageUrl = currentPodcastImage ?? currentEpisode?.imageUrl {
            if let artwork = artworkCache[imageUrl] {
                info[MPMediaItemPropertyArtwork] = artwork
            } else {
                fetchArtwork(imageUrl)
            }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Downloads artwork once per URL and refreshes Now Playing from current
    /// player state on completion, so a slow download can never overwrite the
    /// info center with stale elapsed time or play state.
    private func fetchArtwork(_ imageUrl: String) {
        guard artworkFetchingUrl != imageUrl,
              let url = URL(string: imageUrl), url.scheme == "https" else { return }
        artworkFetchingUrl = imageUrl

        Task.detached(priority: .userInitiated) { [weak self] in
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            let artwork: MPMediaItemArtwork?
            if let (data, _) = try? await URLSession.shared.data(for: request),
               data.count <= 5_000_000,
               let image = UIImage(data: data) {
                artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            } else {
                artwork = nil
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                if self.artworkFetchingUrl == imageUrl {
                    self.artworkFetchingUrl = nil
                }
                guard let artwork else { return }
                if self.artworkCache.count >= 20 {
                    self.artworkCache.removeAll()
                }
                self.artworkCache[imageUrl] = artwork
                self.updateNowPlaying()
            }
        }
    }

    // MARK: - Remote Commands

    private nonisolated func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            DispatchQueue.main.async {
                Task { @MainActor in
                    guard self.player != nil, !self.isPlaying else { return }
                    self.player?.rate = self.playbackSpeed
                    self.isPlaying = true
                    self.updateNowPlaying()
                    self.onRemotePlay?()
                }
            }
            return .success
        }

        center.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            DispatchQueue.main.async {
                Task { @MainActor in
                    guard self.player != nil, self.isPlaying else { return }
                    self.player?.pause()
                    self.isPlaying = false
                    self.updateNowPlaying()
                }
            }
            return .success
        }

        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            DispatchQueue.main.async {
                Task { @MainActor in
                    guard self.player != nil else { return }
                    self.togglePlayPause()
                    if self.isPlaying {
                        self.onRemotePlay?()
                    }
                }
            }
            return .success
        }

        center.skipForwardCommand.preferredIntervals = [NSNumber(value: AppConstants.skipForward)]
        center.skipForwardCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            DispatchQueue.main.async {
                Task { @MainActor in
                    guard self.player != nil else { return }
                    self.skipForward()
                }
            }
            return .success
        }

        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: AppConstants.skipBackward)]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            DispatchQueue.main.async {
                Task { @MainActor in
                    guard self.player != nil else { return }
                    self.skipBackward()
                }
            }
            return .success
        }

        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self else { return .commandFailed }
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = event.positionTime
            DispatchQueue.main.async {
                Task { @MainActor in
                    guard self.player != nil else { return }
                    self.seek(to: position)
                }
            }
            return .success
        }
    }
}
