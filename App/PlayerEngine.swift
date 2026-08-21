// App-target file. AVPlayer-backed playback driven by GeetHubKit's PlaybackQueue.
import Foundation
import AVFoundation
import MediaPlayer
import GeetHubKit

@MainActor
@Observable
final class PlayerEngine {
    private(set) var queue = PlaybackQueue()
    private(set) var isPlaying = false
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0

    var current: Song? { queue.current }
    var hasTrack: Bool { queue.current != nil }

    let client: SubsonicClient
    private let player = AVPlayer()
    private var timeObserver: Any?

    init(client: SubsonicClient) {
        self.client = client
        configureAudioSession()
        addPeriodicTime()
        observeItemEnd()
        setupRemoteCommands()
    }

    // MARK: - Controls

    func play(_ songs: [Song], startAt index: Int = 0) {
        queue.load(songs, startAt: index)
        startCurrent()
    }

    func togglePlayPause() {
        if isPlaying { player.pause(); isPlaying = false }
        else { player.play(); isPlaying = true }
        updateNowPlaying()
    }

    func next() { if queue.next() != nil { startCurrent() } }
    func previous() {
        if currentTime > 3 { seek(to: 0); return }   // restart track first
        if queue.previous() != nil { startCurrent() }
    }

    func seek(to seconds: Double) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        currentTime = seconds
        updateNowPlaying()
    }

    // MARK: - Internals

    private func startCurrent() {
        guard let song = queue.current else { return }
        let item = AVPlayerItem(url: client.streamURL(id: song.id))
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.trackEnded() }
        }
        player.replaceCurrentItem(with: item)
        player.play()
        isPlaying = true
        duration = song.duration.map(Double.init) ?? 0
        currentTime = 0
        updateNowPlaying()
        Task { try? await client.scrobble(id: song.id, submission: false) }  // "now playing"
    }

    private func trackEnded() {
        if queue.next(auto: true) != nil { startCurrent() }
        else { isPlaying = false; updateNowPlaying() }
    }

    private func addPeriodicTime() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] t in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.currentTime = t.seconds
                if self.duration == 0, let d = self.player.currentItem?.duration.seconds, d.isFinite {
                    self.duration = d
                }
            }
        }
    }

    private func observeItemEnd() { /* per-item, wired in startCurrent */ }

    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - Now Playing / remote

    private func setupRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in self?.togglePlayPause(); return .success }
        c.pauseCommand.addTarget { [weak self] _ in self?.togglePlayPause(); return .success }
        c.nextTrackCommand.addTarget { [weak self] _ in self?.next(); return .success }
        c.previousTrackCommand.addTarget { [weak self] _ in self?.previous(); return .success }
    }

    private func updateNowPlaying() {
        guard let song = current else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist ?? "",
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if let album = song.album { info[MPMediaItemPropertyAlbumTitle] = album }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
