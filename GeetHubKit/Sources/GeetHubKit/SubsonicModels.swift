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

    public var isOK: Bool { status == "ok" }
}

public struct SubsonicAPIError: Decodable, Sendable, Error {
    public let code: Int
    public let message: String?
}

// MARK: - Entities

public struct Song: Decodable, Sendable, Identifiable, Hashable {
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
    /// Present (a date string) when the item is starred/favorited.
    public let starred: String?

    /// A virtual YouTube track injected by subsonic-proxy (id like `yt-<videoId>`).
    public var isYouTube: Bool { id.hasPrefix("yt-") }
    public var isFavorite: Bool { starred != nil }
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

public struct PlaylistWithSongs: Decodable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let entry: [Song]?
}
