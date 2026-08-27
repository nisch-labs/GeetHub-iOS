import Foundation

/// A minimal snapshot of what's playing, shared between the app and the
/// widget extension via UserDefaults(suiteName: "group.com.nixsocket.geethub").
///
/// PlayerEngine writes this on every play / pause / next / prev. The widget
/// reads it in its timeline provider. Only the fields the widget UI actually
/// renders are here — deliberately narrow to keep the shared surface tiny.
public struct NowPlayingSnapshot: Codable, Sendable, Equatable {
    public var songId: String
    public var title: String
    public var artist: String?
    public var album: String?
    public var coverArtURL: String?
    public var isPlaying: Bool
    /// Wall-clock timestamp when the snapshot was written — the widget can use
    /// this to gray itself out if the snapshot is stale (e.g. the app has
    /// been killed for a while).
    public var updatedAt: Date

    public init(
        songId: String,
        title: String,
        artist: String? = nil,
        album: String? = nil,
        coverArtURL: String? = nil,
        isPlaying: Bool,
        updatedAt: Date = Date()
    ) {
        self.songId = songId
        self.title = title
        self.artist = artist
        self.album = album
        self.coverArtURL = coverArtURL
        self.isPlaying = isPlaying
        self.updatedAt = updatedAt
    }
}

/// One favourite track summary, shared with the widget's "when idle" view.
public struct FavouriteEntry: Codable, Sendable, Equatable {
    public var songId: String
    public var title: String
    public var artist: String?
    public var coverArtURL: String?
    public init(songId: String, title: String, artist: String? = nil, coverArtURL: String? = nil) {
        self.songId = songId; self.title = title; self.artist = artist; self.coverArtURL = coverArtURL
    }
}

public struct FavouritesSnapshot: Codable, Sendable, Equatable {
    public var songs: [FavouriteEntry]
    public var updatedAt: Date
    public init(songs: [FavouriteEntry], updatedAt: Date = Date()) {
        self.songs = songs; self.updatedAt = updatedAt
    }
}

/// Playback commands the widget/intent can push to the app.
public enum PlayerCommand: String, Codable, Sendable {
    case togglePlayPause, next, previous
}

// MARK: - App Group stores

/// One JSON blob per store under a stable key in the App Group's UserDefaults
/// suite. If the suite isn't available the helpers no-op instead of crashing.
public enum NowPlayingStore {
    public static let appGroup = "group.com.nixsocket.geethub"
    static let key = "geethub.nowPlaying"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    public static func write(_ snapshot: NowPlayingSnapshot?) {
        guard let d = defaults else { return }
        if let snapshot, let data = try? JSONEncoder().encode(snapshot) { d.set(data, forKey: key) }
        else { d.removeObject(forKey: key) }
    }
    public static func read() -> NowPlayingSnapshot? {
        guard let d = defaults, let data = d.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(NowPlayingSnapshot.self, from: data)
    }
}

public enum FavouritesStore {
    static let key = "geethub.favourites"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: NowPlayingStore.appGroup) }

    public static func write(_ snapshot: FavouritesSnapshot?) {
        guard let d = defaults else { return }
        if let snapshot, let data = try? JSONEncoder().encode(snapshot) { d.set(data, forKey: key) }
        else { d.removeObject(forKey: key) }
    }
    public static func read() -> FavouritesSnapshot? {
        guard let d = defaults, let data = d.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(FavouritesSnapshot.self, from: data)
    }
}

/// One-slot command queue — intent writes, app drains + executes.
public enum PlayerCommandStore {
    static let key = "geethub.playerCommand"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: NowPlayingStore.appGroup) }

    public static func push(_ command: PlayerCommand) {
        defaults?.set(command.rawValue, forKey: key)
    }
    /// Read + clear atomically-ish. Called by the app on wake / by a timer.
    public static func pop() -> PlayerCommand? {
        guard let d = defaults, let s = d.string(forKey: key) else { return nil }
        d.removeObject(forKey: key)
        return PlayerCommand(rawValue: s)
    }
}
