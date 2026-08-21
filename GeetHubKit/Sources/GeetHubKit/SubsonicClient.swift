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

    /// Every song (server-paged). Navidrome returns all songs for an empty query.
    public func allSongs(size: Int = 500, offset: Int = 0) async throws -> [Song] {
        try await send("search3.view", [
            .init(name: "query", value: ""),
            .init(name: "songCount", value: String(size)),
            .init(name: "songOffset", value: String(offset)),
            .init(name: "albumCount", value: "0"),
            .init(name: "artistCount", value: "0"),
        ]).searchResult3?.song ?? []
    }

    public func genres() async throws -> [Genre] {
        try await send("getGenres.view").genres?.genre ?? []
    }

    public func songsByGenre(_ genre: String, count: Int = 100) async throws -> [Song] {
        try await send("getSongsByGenre.view", [
            .init(name: "genre", value: genre),
            .init(name: "count", value: String(count)),
        ]).songsByGenre?.song ?? []
    }

    public func artist(id: String) async throws -> ArtistWithAlbums? {
        try await send("getArtist.view", [.init(name: "id", value: id)]).artist
    }

    public func playlists() async throws -> [Playlist] {
        try await send("getPlaylists.view").playlists?.playlist ?? []
    }

    public func createPlaylist(name: String) async throws -> PlaylistWithSongs? {
        try await send("createPlaylist.view", [.init(name: "name", value: name)]).playlist
    }

    /// Structured lyrics (synced if the server has them; else plain lines).
    public func lyrics(id: String) async throws -> [LyricLine] {
        try await send("getLyricsBySongId.view", [.init(name: "id", value: id)])
            .lyricsList?.structuredLyrics?.first?.line ?? []
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

    // MARK: - Favorites

    public func star(id: String) async throws {
        _ = try await send("star.view", [.init(name: "id", value: id)])
    }

    public func unstar(id: String) async throws {
        _ = try await send("unstar.view", [.init(name: "id", value: id)])
    }

    /// Everything the user has favorited (songs/albums/artists).
    public func favorites() async throws -> Starred2 {
        try await send("getStarred2.view").starred2
            ?? Starred2(artist: nil, album: nil, song: nil)
    }

    // MARK: - Smart lists (A + B)

    /// Instant-mix / "start radio" — songs similar to an artist/album/song id.
    public func similarSongs(id: String, count: Int = 50) async throws -> [Song] {
        try await send("getSimilarSongs2.view", [
            .init(name: "id", value: id),
            .init(name: "count", value: String(count)),
        ]).similarSongs2?.song ?? []
    }

    public func randomSongs(count: Int = 50, genre: String? = nil) async throws -> [Song] {
        var p = [URLQueryItem(name: "size", value: String(count))]
        if let genre { p.append(.init(name: "genre", value: genre)) }
        return try await send("getRandomSongs.view", p).randomSongs?.song ?? []
    }

    // MARK: - Save to Library (Geet-Hub proxy extension, not Subsonic)

    /// Ask subsonic-proxy to import a YouTube result into the real library
    /// (hybrid: clean Deezer link → Antra flac, else save the YouTube audio).
    /// `id` is a `yt-<videoId>` from a search result. Fire-and-forget: the proxy
    /// runs the download in the background and Navidrome picks it up on scan.
    public func saveToLibrary(youtubeId: String) async throws {
        var req = URLRequest(url: credentials.baseURL.appendingPathComponent("api/download"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["id": youtubeId])
        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SubsonicClientError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }
}

public enum SubsonicClientError: Error, Sendable {
    case badStatus(Int)
    case notOK(String)
}
