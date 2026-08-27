// App-target file. AVPlayer-backed playback driven by GeetHubKit's PlaybackQueue.
import Foundation
import AVFoundation
import MediaPlayer
import UIKit
import WidgetKit
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

    // Shuffle / repeat (delegated to the queue).
    var isShuffled: Bool { queue.isShuffled }
    var repeatMode: PlaybackQueue.RepeatMode { queue.repeatMode }
    func toggleShuffle() { queue.toggleShuffle() }
    func cycleRepeat() {
        switch queue.repeatMode {
        case .off: queue.repeatMode = .all
        case .all: queue.repeatMode = .one
        case .one: queue.repeatMode = .off
        }
    }

    // Favorites (optimistic; persisted to the server) — works for any song.
    private var favoriteOverride: [String: Bool] = [:]
    func isFavorite(_ song: Song) -> Bool { favoriteOverride[song.id] ?? song.isFavorite }
    func setFavorite(_ song: Song) {
        let newValue = !isFavorite(song)
        favoriteOverride[song.id] = newValue
        Task { try? await (newValue ? client.star(id: song.id) : client.unstar(id: song.id)) }
    }
    var isCurrentFavorite: Bool { current.map(isFavorite) ?? false }
    func toggleFavorite() { if let s = current { setFavorite(s) } }

    // Recently played (local, persisted) — reflects what you actually played here.
    private(set) var recentlyPlayed: [Song] = []
    private let recentlyPlayedKey = "recentlyPlayedSongs"
    private func loadRecentlyPlayed() {
        if let data = UserDefaults.standard.data(forKey: recentlyPlayedKey),
           let songs = try? JSONDecoder().decode([Song].self, from: data) {
            recentlyPlayed = Array(songs.prefix(10))
        }
    }
    private func recordPlayed(_ song: Song) {
        recentlyPlayed.removeAll { $0.id == song.id }
        recentlyPlayed.insert(song, at: 0)
        if recentlyPlayed.count > 10 { recentlyPlayed = Array(recentlyPlayed.prefix(10)) }
        if let data = try? JSONEncoder().encode(recentlyPlayed) {
            UserDefaults.standard.set(data, forKey: recentlyPlayedKey)
        }
    }
    func clearRecentlyPlayed() {
        recentlyPlayed = []
        UserDefaults.standard.removeObject(forKey: recentlyPlayedKey)
    }
    func clearSavedYouTube() {
        savedYouTube.removeAll()
        failedDownloads.removeAll()
    }

    // Save a YouTube track into the real library (via the proxy).
    // Progress dict: yt-id → percent while in flight (nil = not downloading).
    // Failed set lets rows/player show a retry affordance.
    private(set) var savedYouTube: Set<String> = []
    private(set) var downloads: [String: Int] = [:]
    private(set) var failedDownloads: Set<String> = []
    var isCurrentSaved: Bool { current.map { savedYouTube.contains($0.id) } ?? false }
    var currentDownloadPercent: Int? { current.flatMap { downloads[$0.id] } }

    func startedDownload(_ id: String) {
        failedDownloads.remove(id)
        downloads[id] = 0
    }
    func setDownloadProgress(_ id: String, percent: Int) {
        guard downloads[id] != nil else { return }
        downloads[id] = max(0, min(99, percent))
    }
    func finishedDownload(_ id: String, success: Bool) {
        downloads.removeValue(forKey: id)
        if success { savedYouTube.insert(id) } else { failedDownloads.insert(id) }
    }

    func saveCurrentToLibrary() {
        guard let s = current, s.isVirtual, !savedYouTube.contains(s.id),
              downloads[s.id] == nil else { return }
        startedDownload(s.id)
        Task {
            do {
                let did = try await client.startSave(youtubeId: s.id)
                guard let did else { finishedDownload(s.id, success: true); return }
                var errors = 0
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    do {
                        let st = try await client.downloadStatus(downloadId: did)
                        errors = 0
                        if st.state == "done" { finishedDownload(s.id, success: true); return }
                        if st.state == "failed" { finishedDownload(s.id, success: false); return }
                        setDownloadProgress(s.id, percent: st.percent)
                    } catch {
                        errors += 1
                        if errors >= 5 { finishedDownload(s.id, success: false); return }
                    }
                }
            } catch {
                finishedDownload(s.id, success: false)
            }
        }
    }

    // Queue editing / Up Next.
    var upNext: [Song] { queue.upNext }
    func enqueueNext(_ song: Song) {
        let wasEmpty = current == nil
        queue.playNext(song)
        if wasEmpty { startCurrent() }
    }
    func enqueueLast(_ song: Song) {
        let wasEmpty = current == nil
        queue.append(song)
        if wasEmpty { startCurrent() }
    }
    func playUpNext(_ index: Int) {
        let target = (queue.position ?? -1) + 1 + index
        queue.jump(to: target)
        startCurrent()
    }
    func removeUpNext(_ index: Int) {
        let target = (queue.position ?? -1) + 1 + index
        queue.remove(atOrderPosition: target)
    }

    // Sleep timer.
    private(set) var sleepEndsAt: Date?
    private var sleepTask: Task<Void, Never>?
    var isSleepArmed: Bool { sleepEndsAt != nil }
    func setSleep(minutes: Int?) {
        sleepTask?.cancel()
        guard let minutes else { sleepEndsAt = nil; return }
        sleepEndsAt = Date().addingTimeInterval(Double(minutes * 60))
        sleepTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Double(minutes * 60)))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                if self.isPlaying { self.togglePlayPause() }
                self.sleepEndsAt = nil
            }
        }
    }

    let client: SubsonicClient
    private let player = AVPlayer()
    private var timeObserver: Any?

    // Per-app volume (0.0–1.0). Applies to this AVPlayer only, not the system
    // volume — so hardware buttons keep working normally and this lets you dial
    // the app quieter without touching every other app.
    private static let volumeKey = "geethub.volume"
    private(set) var volume: Float = {
        let stored = UserDefaults.standard.object(forKey: PlayerEngine.volumeKey) as? Float
        return stored.map { max(0, min(1, $0)) } ?? 1.0
    }()
    func setVolume(_ v: Float) {
        let clamped = max(0, min(1, v))
        volume = clamped
        player.volume = clamped
        UserDefaults.standard.set(clamped, forKey: PlayerEngine.volumeKey)
    }

    // MARK: - Multi-device sync (Devices menu)
    //
    // Every client heartbeats to the proxy so all of the user's devices see
    // each other. Transferring playback drops a command into the target's
    // queue; both devices react on their poll cycle.
    private static let deviceIdKey = "geethub.deviceId"
    private(set) var deviceId: String = {
        if let v = UserDefaults.standard.string(forKey: PlayerEngine.deviceIdKey) { return v }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: PlayerEngine.deviceIdKey)
        return fresh
    }()
    private(set) var devices: [Device] = []
    private var heartbeatTimer: Timer?
    private var deviceCmdTimer: Timer?

    private var deviceKind: String {
        #if targetEnvironment(macCatalyst)
        return "mac"
        #else
        return UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        #endif
    }
    private var deviceName: String {
        // e.g. "Nischal's iPhone" — provided by the OS.
        UIDevice.current.name
    }

    init(client: SubsonicClient) {
        self.client = client
        configureAudioSession()
        player.volume = volume
        addPeriodicTime()
        observeItemEnd()
        setupRemoteCommands()
        loadRecentlyPlayed()
        // Enable remote-control event routing. On Mac Catalyst this is what
        // makes the F7/F8/F9 media keys reach MPRemoteCommandCenter — without
        // it, macOS ignores us in favour of Music.app / Spotify / whoever last
        // played. Deprecated on iOS 13+ (superseded by MPRemoteCommandCenter
        // targets, which we also set up) but still required for key routing.
        UIApplication.shared.beginReceivingRemoteControlEvents()
        startCommandDrain()
        Task { await refreshFavouritesSnapshot() }
        startDeviceSync()
    }

    // MARK: - Device sync loops

    private func startDeviceSync() {
        // Kick off an immediate heartbeat + device list refresh.
        Task { await self.pushHeartbeat() }
        Task { await self.refreshDevices() }

        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.pushHeartbeat()
                await self?.refreshDevices()
            }
        }
        deviceCmdTimer?.invalidate()
        deviceCmdTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.drainDeviceCommands() }
        }
    }

    /// Snapshot of the currently-playing song for heartbeat/transfer payloads.
    private func makeDeviceSong() -> DeviceSong? {
        guard let s = current else { return nil }
        return DeviceSong(id: s.id, title: s.title, artist: s.artist,
                          album: s.album, coverArt: s.coverArt, duration: s.duration)
    }

    func pushHeartbeat() async {
        let payload = DeviceHeartbeat(
            id: deviceId,
            name: deviceName,
            kind: deviceKind,
            isPlaying: isPlaying,
            currentSong: makeDeviceSong(),
            position: currentTime,
            duration: duration,
        )
        _ = try? await client.deviceHeartbeat(payload: payload)
    }

    func refreshDevices() async {
        let list = (try? await client.listDevices()) ?? []
        devices = list
    }

    private func drainDeviceCommands() async {
        let commands = (try? await client.pollDeviceCommands(deviceId: deviceId)) ?? []
        for cmd in commands {
            switch cmd.type {
            case "pause":
                if isPlaying { togglePlayPause() }
            case "play":
                if let song = cmd.song {
                    // Reconstruct a Song from the DeviceSong payload — enough
                    // to start playback; extra metadata will be right on next
                    // library refresh.
                    let s = Song(
                        id: song.id, title: song.title,
                        album: song.album, albumId: nil,
                        artist: song.artist, artistId: nil,
                        coverArt: song.coverArt, duration: song.duration,
                        track: nil, year: nil, size: nil, suffix: nil,
                        contentType: nil, isVideo: nil,
                        created: nil, playCount: nil, starred: nil,
                    )
                    play([s], startAt: 0)
                    if let pos = cmd.position, pos > 0 {
                        // Give the item a moment to load before seeking.
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(400))
                            self.seek(to: pos)
                        }
                    }
                }
            default:
                break
            }
        }
    }

    /// User picked a device from the sheet — send `play(song, pos)` there
    /// and pause locally.
    func transferPlayback(to targetId: String) async {
        guard let song = makeDeviceSong() else { return }
        let pos = currentTime
        // Pause locally immediately so the same track isn't playing on both.
        if isPlaying { togglePlayPause() }
        _ = try? await client.transferPlayback(
            toDeviceId: targetId, sourceDeviceId: deviceId,
            song: song, position: pos,
        )
        // Refresh the list so the target's isPlaying flips soon.
        Task { try? await Task.sleep(for: .seconds(2)); await refreshDevices() }
    }

    // MARK: - Widget bridge (playback intents + favourites)

    /// Poll the shared command queue every 1s. When the widget's App Intent
    /// runs, it pushes a command to shared UserDefaults; we drain it here.
    /// iOS 17+ AudioPlaybackIntent will background-launch the app if needed,
    /// so this timer starts firing shortly after and the command is picked up.
    private var commandDrainTimer: Timer?
    private func startCommandDrain() {
        commandDrainTimer?.invalidate()
        commandDrainTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard let cmd = PlayerCommandStore.pop() else { return }
                switch cmd {
                case .togglePlayPause: self.togglePlayPause()
                case .next:            self.next()
                case .previous:        self.previous()
                }
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        // Also drain immediately in case a command was queued while the app
        // was suspended.
        Task { @MainActor in
            if let cmd = PlayerCommandStore.pop() {
                switch cmd {
                case .togglePlayPause: togglePlayPause()
                case .next:            next()
                case .previous:        previous()
                }
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    /// Publish up to 8 starred songs to the App Group so the widget can show
    /// them in its "no playback" state. Called on startup and can be called
    /// again after the user stars/unstars a track.
    func refreshFavouritesSnapshot() async {
        guard let starred = try? await client.favorites().song else { return }
        let entries: [FavouriteEntry] = starred.prefix(8).map { s in
            FavouriteEntry(
                songId: s.id, title: s.title, artist: s.artist,
                coverArtURL: s.coverArt.map { client.coverArtURL(id: $0, size: 300).absoluteString },
            )
        }
        FavouritesStore.write(FavouritesSnapshot(songs: entries))
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Controls

    func play(_ songs: [Song], startAt index: Int = 0) {
        queue.load(songs, startAt: index)
        startCurrent()
    }

    func playShuffled(_ songs: [Song]) {
        guard !songs.isEmpty else { return }
        if !queue.isShuffled { queue.setShuffled(true) }
        queue.load(songs, startAt: Int.random(in: 0..<songs.count))
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
        recordPlayed(song)
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
        // AVAudioSession is an iOS concept for coordinating with other apps.
        // Mac Catalyst doesn't have it (macOS handles audio at the OS level).
        #if !targetEnvironment(macCatalyst)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }

    // MARK: - Now Playing / remote

    private func setupRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in
            if let self, !self.isPlaying { self.togglePlayPause() }
            return .success
        }
        c.pauseCommand.addTarget { [weak self] _ in
            if let self, self.isPlaying { self.togglePlayPause() }
            return .success
        }
        // Mac's F8 / headphones send togglePlayPauseCommand specifically.
        c.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause(); return .success
        }
        c.nextTrackCommand.addTarget { [weak self] _ in self?.next(); return .success }
        c.previousTrackCommand.addTarget { [weak self] _ in self?.previous(); return .success }
    }

    // Cache one artwork per song id — lock-screen/control-centre pull the same
    // asset many times per second while the scrubber ticks, and we'd otherwise
    // re-fetch on every updateNowPlaying() call.
    private var artworkCache: [String: MPMediaItemArtwork] = [:]

    private func updateNowPlaying() {
        let center = MPNowPlayingInfoCenter.default()
        guard let song = current else {
            center.nowPlayingInfo = nil
            center.playbackState = .stopped
            NowPlayingStore.write(nil)
            WidgetCenter.shared.reloadAllTimelines()
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
        if let art = artworkCache[song.id] {
            info[MPMediaItemPropertyArtwork] = art
        }
        center.nowPlayingInfo = info
        center.playbackState = isPlaying ? .playing : .paused

        // Mirror the same state into the App Group so the widget can read it.
        NowPlayingStore.write(NowPlayingSnapshot(
            songId: song.id,
            title: song.title,
            artist: song.artist,
            album: song.album,
            coverArtURL: song.coverArt.map { client.coverArtURL(id: $0, size: 300).absoluteString },
            isPlaying: isPlaying,
        ))
        WidgetCenter.shared.reloadAllTimelines()

        // Fetch artwork out-of-band the first time we see this song. Once cached,
        // subsequent updateNowPlaying calls include it immediately (line above).
        if artworkCache[song.id] == nil, let artId = song.coverArt {
            let songId = song.id
            let url = client.coverArtURL(id: artId, size: 600)
            Task { [weak self] in
                guard let (data, _) = try? await URLSession.shared.data(from: url),
                      let image = UIImage(data: data) else { return }
                // MediaPlayer calls the request handler on its own dispatch queue,
                // so the closure MUST NOT inherit @MainActor isolation — Swift 6
                // strict concurrency will trap otherwise. Build it in a nonisolated
                // helper so the closure captures no actor context.
                let art = Self.makeArtwork(from: image)
                await MainActor.run {
                    guard let self else { return }
                    self.artworkCache[songId] = art
                    if self.current?.id == songId { self.updateNowPlaying() }
                }
            }
        }
    }

    private nonisolated static func makeArtwork(from image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }
}
