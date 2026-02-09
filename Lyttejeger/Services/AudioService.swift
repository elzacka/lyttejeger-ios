import Foundation
import AVFoundation
import MediaPlayer
import UIKit

@Observable
@MainActor
final class AudioService {
    static let shared = AudioService()

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var statusCheckTask: Task<Void, Never>?
    private var endOfPlaybackObserver: (any NSObjectProtocol)?

    // MARK: - State

    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var isLoading = false
    var hasError = false
    var playbackSpeed: Float = 1.0

    // MARK: - Current Episode

    var currentEpisode: Episode?
    var currentPodcastTitle: String?
    var currentPodcastImage: String?

    private init() {
        setupAudioSession()
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
            print("Audio session setup failed: \(error)")
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

        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.automaticallyWaitsToMinimizeStalling = true

        // Poll for readyToPlay entirely on MainActor.
        // KVO on AVPlayerItem.status fires on background threads and the KVO
        // machinery itself reads .status off-main, triggering iOS 26's
        // _dispatch_assert_queue_fail. Polling avoids KVO entirely.
        statusCheckTask = Task { @MainActor in
            for _ in 0..<300 { // up to 30 seconds at 100ms intervals
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
                try? await Task.sleep(for: .milliseconds(100))
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
        } else {
            // Setting rate to non-zero resumes at the correct speed (no need for play() + rate)
            player.rate = playbackSpeed
            isPlaying = true
        }
        updateNowPlaying()
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

    func seekToPosition(_ position: TimeInterval) {
        seek(to: position)
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
    }

    // MARK: - Now Playing

    private func updateNowPlaying() {
        // Capture values to avoid accessing @MainActor properties from background
        let episodeTitle = currentEpisode?.title ?? ""
        let podcastTitle = currentPodcastTitle ?? ""
        let time = currentTime
        let dur = duration
        let playing = isPlaying
        let speed = playbackSpeed
        let imageUrl = currentPodcastImage ?? currentEpisode?.imageUrl

        // All MPNowPlayingInfoCenter access must happen on main queue
        // Use sync if already on main, async otherwise
        if Thread.isMainThread {
            self.updateNowPlayingOnMainThread(
                episodeTitle: episodeTitle,
                podcastTitle: podcastTitle,
                time: time,
                duration: dur,
                playing: playing,
                speed: speed,
                imageUrl: imageUrl
            )
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.updateNowPlayingOnMainThread(
                    episodeTitle: episodeTitle,
                    podcastTitle: podcastTitle,
                    time: time,
                    duration: dur,
                    playing: playing,
                    speed: speed,
                    imageUrl: imageUrl
                )
            }
        }
    }

    private nonisolated func updateNowPlayingOnMainThread(
        episodeTitle: String,
        podcastTitle: String,
        time: TimeInterval,
        duration: TimeInterval,
        playing: Bool,
        speed: Float,
        imageUrl: String?
    ) {
        let info: [String: Any] = [
            MPMediaItemPropertyTitle: episodeTitle,
            MPMediaItemPropertyArtist: podcastTitle,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: time,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: playing ? Double(speed) : 0.0
        ]

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        // Load artwork async - use DispatchQueue.global to avoid actor context
        if let imageUrl, let url = URL(string: imageUrl) {
            DispatchQueue.global(qos: .userInitiated).async {
                if let data = try? Data(contentsOf: url),
                   let image = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    // Capture episodeTitle to verify we're updating the right episode
                    let capturedTitle = episodeTitle
                    DispatchQueue.main.async {
                        // Build a fresh info dict to avoid Sendable issues
                        let updatedInfo: [String: Any] = [
                            MPMediaItemPropertyTitle: capturedTitle,
                            MPMediaItemPropertyArtist: podcastTitle,
                            MPNowPlayingInfoPropertyElapsedPlaybackTime: time,
                            MPMediaItemPropertyPlaybackDuration: duration,
                            MPNowPlayingInfoPropertyPlaybackRate: playing ? Double(speed) : 0.0,
                            MPMediaItemPropertyArtwork: artwork
                        ]
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
                    }
                }
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
                    guard self.player != nil else { return }
                    self.togglePlayPause()
                }
            }
            return .success
        }

        center.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            DispatchQueue.main.async {
                Task { @MainActor in
                    guard self.player != nil else { return }
                    self.togglePlayPause()
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
