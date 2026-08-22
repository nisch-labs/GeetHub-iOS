import Foundation

// MARK: - Response envelope

/// Subsonic wraps every payload in `{"subsonic-response": { ... }}`.
struct SubsonicEnvelope: Decodable {
    let subsonicResponse: SubsonicResponse
    enum CodingKeys: String, CodingKey { case subsonicResponse = "subsonic-response" }
}

/// One flat response type with optional fields per endpoint — simpler than a
/// generic wrapper and matches how Navidrome returns `f=json`.
public struct SubsonicResponse: Decodable, Sendable {
    public let status: String
    public let version: String
    public let error: SubsonicAPIError?

    public let searchResult3: SearchResult3?
    public let artists: ArtistsIndex?
    public let albumList2: AlbumList2?
    public let album: AlbumWithSongs?
    public let playlists: Playlists?
    public let playlist: PlaylistWithSongs?
    public let starred2: Starred2?
    public let similarSongs2: SimilarSongs2?
    public let randomSongs: RandomSongs?
    public let genres: Genres?
    public let songsByGenre: SongsByGenre?
    public let artist: ArtistWithAlbums?
    public let lyricsList: LyricsList?

    public var isOK: Bool { status == "ok" }
}

public struct SubsonicAPIError: Decodable, Sendable, Error {
    public let code: Int
    public let message: String?
}

// MARK: - Entities

public struct Song: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let title: String
    public let album: String?
    public let albumId: String?
    public let artist: String?
    public let artistId: String?
    public let coverArt: String?
    public let duration: Int?
    public let track: Int?
    public let year: Int?
    public let size: Int?
    public let suffix: String?
    public let contentType: String?
    public let isVideo: Bool?
    /// ISO-8601 date the track was added to the library (sortable lexically).
    public let created: String?
    /// Number of times the track has been played (server-side).
    public let playCount: Int?
    /// Present (a date string) when the item is starred/favorited.
    public let starred: String?

    /// The provenance of a virtual track injected by subsonic-proxy — encoded
    /// as an id prefix (`yt-` for YouTube search, `ytm-` for YouTube Music).
    /// `nil` for real library songs.
    public var virtualSource: VirtualSource? {
        if id.hasPrefix("ytm-") { return .youtubeMusic }
        if id.hasPrefix("yt-")  { return .youtube }
        return nil
    }
    public var isVirtual: Bool { virtualSource != nil }
    /// Backward-compat alias for the original yt- prefix (regular YouTube).
    public var isYouTube: Bool { virtualSource == .youtube }
    public var isYouTubeMusic: Bool { virtualSource == .youtubeMusic }
    public var isFavorite: Bool { starred != nil }
}

public enum VirtualSource: String, Sendable {
    case youtube, youtubeMusic
    public var shortLabel: String {
        switch self {
        case .youtube:      return "YT"
        case .youtubeMusic: return "YT Music"
        }
    }
}

public struct Album: Decodable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let artist: String?
    public let artistId: String?
    public let coverArt: String?
    public let songCount: Int?
    public let duration: Int?
    public let year: Int?
    public let starred: String?

    public var isFavorite: Bool { starred != nil }
}

public struct Artist: Decodable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let coverArt: String?
    public let albumCount: Int?
    public let starred: String?

    public var isFavorite: Bool { starred != nil }
}

public struct Playlist: Decodable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let songCount: Int?
    public let duration: Int?
    public let owner: String?
    public let `public`: Bool?
    public let coverArt: String?
}

// MARK: - Containers

public struct SearchResult3: Decodable, Sendable {
    public let artist: [Artist]?
    public let album: [Album]?
    public let song: [Song]?
}

public struct ArtistsIndex: Decodable, Sendable {
    public struct Index: Decodable, Sendable {
        public let name: String
        public let artist: [Artist]?
    }
    public let index: [Index]?

    public var allArtists: [Artist] { (index ?? []).flatMap { $0.artist ?? [] } }
}

public struct AlbumList2: Decodable, Sendable {
    public let album: [Album]?
}

public struct AlbumWithSongs: Decodable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let artist: String?
    public let coverArt: String?
    public let song: [Song]?
}

public struct Playlists: Decodable, Sendable {
    public let playlist: [Playlist]?
}

public struct Starred2: Decodable, Sendable {
    public let artist: [Artist]?
    public let album: [Album]?
    public let song: [Song]?
}

public struct SimilarSongs2: Decodable, Sendable {
    public let song: [Song]?
}

public struct RandomSongs: Decodable, Sendable {
    public let song: [Song]?
}

public struct Genre: Decodable, Sendable, Identifiable, Hashable {
    public let value: String
    public let songCount: Int?
    public var id: String { value }
    public var name: String { value }
}

public struct Genres: Decodable, Sendable {
    public let genre: [Genre]?
}

public struct SongsByGenre: Decodable, Sendable {
    public let song: [Song]?
}

public struct ArtistWithAlbums: Decodable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let album: [Album]?
}

public struct LyricsList: Decodable, Sendable {
    public let structuredLyrics: [StructuredLyrics]?
}

public struct StructuredLyrics: Decodable, Sendable {
    public let synced: Bool?
    public let line: [LyricLine]?
}

public struct LyricLine: Decodable, Sendable, Identifiable, Hashable {
    public let start: Int?     // milliseconds (synced lyrics)
    public let value: String
    public var id: String { "\(start ?? -1)-\(value)" }
}

public struct PlaylistWithSongs: Decodable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let entry: [Song]?
}
