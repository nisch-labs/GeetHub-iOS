import Foundation

/// A thin, streaming-first Subsonic API client.
///
/// Design note: there is deliberately **no local library mirror / persistence**.
/// Browse and search hit the server live and return values in memory — so a
/// search never writes anything to disk. This is exactly what makes Geet-Hub's
/// "nothing from search persists" behavior automatic (unlike Amperfy's Core Data
/// sync model). Anything the user wants to keep is an explicit action (e.g.
/// adding a track to the "Download via Antra" playlist, which the proxy acts on).
public struct SubsonicClient: Sendable {
    public let credentials: SubsonicCredentials
    private let session: URLSession

    public init(credentials: SubsonicCredentials, session: URLSession = .shared) {
        self.credentials = credentials
        self.session = session
    }

    // MARK: - URL building

    /// Build a full request URL for a Subsonic view + params (auth appended).
    public func url(_ view: String, _ params: [URLQueryItem] = []) -> URL {
        var comps = URLComponents(
            url: credentials.baseURL.appendingPathComponent("rest/\(view)"),
            resolvingAgainstBaseURL: false
        )!
        comps.queryItems = params + credentials.authQueryItems()
        return comps.url!
    }

    /// Streamable URL for a song id (feed straight to AVPlayer).
    public func streamURL(id: String) -> URL { url("stream.view", [.init(name: "id", value: id)]) }

    /// Cover-art URL for an id (song/album/artist or a `yt-` virtual track).
    public func coverArtURL(id: String, size: Int? = nil) -> URL {
        var p = [URLQueryItem(name: "id", value: id)]
        if let size { p.append(.init(name: "size", value: String(size))) }
        return url("getCoverArt.view", p)
    }

    // MARK: - Requests

    private func send(_ view: String, _ params: [URLQueryItem] = []) async throws -> SubsonicResponse {
        let (data, response) = try await session.data(from: url(view, params))
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SubsonicClientError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let decoded = try JSONDecoder().decode(SubsonicEnvelope.self, from: data).subsonicResponse
        if let err = decoded.error { throw err }
        guard decoded.isOK else { throw SubsonicClientError.notOK(decoded.status) }
        return decoded
    }

    // MARK: - Endpoints (v1)

    public func ping() async throws {
        _ = try await send("ping.view")
    }

    public func artists() async throws -> [Artist] {
        try await send("getArtists.view").artists?.allArtists ?? []
    }

    /// `type` e.g. "newest", "recent", "alphabeticalByName", "frequent".
    public func albumList(type: String = "alphabeticalByName", size: Int = 100, offset: Int = 0) async throws -> [Album] {
        try await send("getAlbumList2.view", [
            .init(name: "type", value: type),
            .init(name: "size", value: String(size)),
            .init(name: "offset", value: String(offset)),
        ]).albumList2?.album ?? []
    }

    public func album(id: String) async throws -> AlbumWithSongs? {
        try await send("getAlbum.view", [.init(name: "id", value: id)]).album
    }

    /// Live server search. Results are transient — never persisted. YouTube
    /// virtual tracks (from subsonic-proxy) arrive here just like real songs.
    public func search(_ query: String, artistCount: Int = 20, albumCount: Int = 20, songCount: Int = 40) async throws -> SearchResult3 {
        let r = try await send("search3.view", [
            .init(name: "query", value: query),
            .init(name: "artistCount", value: String(artistCount)),
            .init(name: "albumCount", value: String(albumCount)),
            .init(name: "songCount", value: String(songCount)),
        ])
        return r.searchResult3 ?? SearchResult3(artist: nil, album: nil, song: nil)
    }

    public func playlists() async throws -> [Playlist] {
        try await send("getPlaylists.view").playlists?.playlist ?? []
    }

    public func playlist(id: String) async throws -> PlaylistWithSongs? {
        try await send("getPlaylist.view", [.init(name: "id", value: id)]).playlist
    }

    /// Add a song to a playlist. Adding a `yt-` track to the "Download via Antra"
    /// playlist triggers the proxy's hybrid download — no other client work needed.
    public func addToPlaylist(playlistId: String, songId: String) async throws {
        _ = try await send("updatePlaylist.view", [
            .init(name: "playlistId", value: playlistId),
            .init(name: "songIdToAdd", value: songId),
        ])
    }

    public func removeFromPlaylist(playlistId: String, index: Int) async throws {
        _ = try await send("updatePlaylist.view", [
            .init(name: "playlistId", value: playlistId),
            .init(name: "songIndexToRemove", value: String(index)),
        ])
    }

    public func scrobble(id: String, submission: Bool = true) async throws {
        _ = try await send("scrobble.view", [
            .init(name: "id", value: id),
            .init(name: "submission", value: submission ? "true" : "false"),
        ])
    }
}

public enum SubsonicClientError: Error, Sendable {
    case badStatus(Int)
    case notOK(String)
}
