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
    /// ``ytSource`` picks the proxy's augment engine: ``"youtube"`` (broad,
    /// noisier) or ``"ytmusic"`` (cleaner, song-only). Nil = proxy default.
    public func search(_ query: String,
                       artistCount: Int = 20,
                       albumCount: Int = 20,
                       songCount: Int = 40,
                       ytSource: String? = nil) async throws -> SearchResult3 {
        var params: [URLQueryItem] = [
            .init(name: "query", value: query),
            .init(name: "artistCount", value: String(artistCount)),
            .init(name: "albumCount", value: String(albumCount)),
            .init(name: "songCount", value: String(songCount)),
        ]
        if let ytSource, !ytSource.isEmpty {
            params.append(.init(name: "ytSource", value: ytSource))
        }
        let r = try await send("search3.view", params)
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

    /// Library folders the proxy/Antra know about — for the folder picker.
    /// Returns an empty list against a proxy that predates this endpoint.
    public func libraryFolders() async throws -> [String] {
        let url = credentials.baseURL.appendingPathComponent("api/folders")
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw SubsonicClientError.badStatus(-1)
        }
        if http.statusCode == 404 { return [] }
        guard (200..<300).contains(http.statusCode) else {
            throw SubsonicClientError.badStatus(http.statusCode)
        }
        struct FoldersResp: Decodable { let folders: [String] }
        return (try JSONDecoder().decode(FoldersResp.self, from: data)).folders
    }

    /// Ask subsonic-proxy to import a YouTube result into the real library
    /// (hybrid: clean Deezer link → Antra flac, else save the YouTube audio).
    /// Returns a `download_id` the app can poll via ``downloadStatus``. Older
    /// proxy builds that don't return an id yield `nil` — caller should treat
    /// that as fire-and-forget and skip polling.
    @discardableResult
    public func startSave(youtubeId: String, folder: String? = nil) async throws -> String? {
        var req = URLRequest(url: credentials.baseURL.appendingPathComponent("api/download"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: String] = ["id": youtubeId]
        if let folder, !folder.isEmpty { body["folder"] = folder }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SubsonicClientError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        struct StartResp: Decodable { let download_id: String? }
        return (try? JSONDecoder().decode(StartResp.self, from: data))?.download_id
    }

    // MARK: - Antra pass-through (any-URL job queue)

    /// Queue any Antra-supported URL (Spotify / YouTube / Deezer / Apple Music
    /// / Tidal playlist, album, or track) as an Antra job via the proxy.
    /// Returns the numeric Antra job id.
    @discardableResult
    public func startAntraDownload(url: String, format: String = "mp3",
                                   folder: String? = nil) async throws -> Int {
        var req = URLRequest(url: credentials.baseURL.appendingPathComponent("api/antra/download"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: String] = ["url": url, "format": format]
        if let folder, !folder.isEmpty { body["folder"] = folder }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SubsonicClientError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        struct Resp: Decodable { let job_id: Int }
        return (try JSONDecoder().decode(Resp.self, from: data)).job_id
    }

    /// List all Antra jobs (newest activity first, per Antra's ordering).
    public func antraJobs() async throws -> [AntraJob] {
        let url = credentials.baseURL.appendingPathComponent("api/antra/jobs")
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SubsonicClientError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return (try? JSONDecoder().decode([AntraJob].self, from: data)) ?? []
    }

    /// One Antra job with parsed progress (0..99) filled in when in-flight.
    public func antraJobStatus(id: Int) async throws -> AntraJob {
        let url = credentials.baseURL.appendingPathComponent("api/antra/jobs/\(id)")
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SubsonicClientError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(AntraJob.self, from: data)
    }

    /// Per-track state for a playlist/album job. Empty for single-track jobs.
    public func antraJobTracks(id: Int) async throws -> [AntraTrack] {
        let url = credentials.baseURL.appendingPathComponent("api/antra/jobs/\(id)/tracks")
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SubsonicClientError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return (try? JSONDecoder().decode([AntraTrack].self, from: data)) ?? []
    }

    // ─── Multi-device sync ────────────────────────────────────

    /// Register / update this device in the proxy's registry. Called on
    /// launch and every ~15s from PlayerEngine. Returns the server-echoed
    /// device record (with `id` filled if the caller passed nil).
    @discardableResult
    public func deviceHeartbeat(payload: DeviceHeartbeat) async throws -> Device {
        var comps = URLComponents(url: credentials.baseURL.appendingPathComponent("api/devices/heartbeat"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [.init(name: "u", value: credentials.username)]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(payload)
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SubsonicClientError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(Device.self, from: data)
    }

    /// List this account's currently-registered devices (heartbeated within 2 min).
    public func listDevices() async throws -> [Device] {
        var comps = URLComponents(url: credentials.baseURL.appendingPathComponent("api/devices"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [.init(name: "u", value: credentials.username)]
        var req = URLRequest(url: comps.url!)
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SubsonicClientError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return (try? JSONDecoder().decode([Device].self, from: data)) ?? []
    }

    /// Drain pending commands (play/pause) for `deviceId` — clients poll
    /// this every ~3s to react to transfers initiated from other devices.
    public func pollDeviceCommands(deviceId: String) async throws -> [DeviceCommand] {
        var comps = URLComponents(url: credentials.baseURL.appendingPathComponent("api/devices/\(deviceId)/commands"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [.init(name: "u", value: credentials.username)]
        var req = URLRequest(url: comps.url!)
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SubsonicClientError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return (try? JSONDecoder().decode([DeviceCommand].self, from: data)) ?? []
    }

    /// Ask the proxy to queue a `play` command on the target device and a
    /// `pause` command on the source. Source device should pause itself
    /// immediately (don't wait for the round-trip).
    public func transferPlayback(
        toDeviceId targetId: String,
        sourceDeviceId: String?,
        song: DeviceSong,
        position: Double,
    ) async throws {
        var comps = URLComponents(url: credentials.baseURL.appendingPathComponent("api/devices/\(targetId)/transfer"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [.init(name: "u", value: credentials.username)]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        struct Body: Encodable { let source_id: String?; let song: DeviceSong; let position: Double }
        req.httpBody = try JSONEncoder().encode(Body(source_id: sourceDeviceId, song: song, position: position))
        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SubsonicClientError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    public func downloadStatus(downloadId: String) async throws -> DownloadStatus {
        var comps = URLComponents(url: credentials.baseURL.appendingPathComponent("api/download/status"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [.init(name: "id", value: downloadId)]
        // Bypass URLCache — status polling depends on seeing the latest state,
        // and a cached "queued/downloading" response would trap us in an
        // infinite poll loop even after the proxy returns "done".
        var req = URLRequest(url: comps.url!)
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SubsonicClientError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(DownloadStatus.self, from: data)
    }
}

/// One track inside a playlist/album Antra job.
public struct AntraTrack: Codable, Sendable, Identifiable, Hashable {
    public let index: Int
    public let total: Int
    public let artist: String?
    public let title: String
    /// One of: `queued`, `downloading`, `done`, `skipped`, `failed`.
    public let state: String

    public var id: Int { index }
}

/// One Antra job — a download of a Spotify/YouTube/etc. URL. Fields mirror
/// Antra's own /api/jobs shape with an added ``progress`` (0..99) parsed by
/// the proxy from the job's log tail.
public struct AntraJob: Codable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let url: String
    public let title: String?
    public let source: String?
    public let format: String?
    public let folder: String?
    public let status: String            // queued · running · done · error · failed
    public let created: Double?
    public let finished: Double?
    public let exit_code: Int?
    public let owner: String?
    public let progress: Int?            // filled in by the proxy for GET /api/antra/jobs/{id}

    public var isTerminal: Bool { status == "done" || status == "error" || status == "failed" }
}

// MARK: - Multi-device sync types

/// A summary of the currently-playing track, small enough to fit in a
/// device heartbeat or a transfer command.
public struct DeviceSong: Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let artist: String?
    public let album: String?
    public let coverArt: String?
    public let duration: Int?
    public init(id: String, title: String, artist: String? = nil, album: String? = nil,
                coverArt: String? = nil, duration: Int? = nil) {
        self.id = id; self.title = title; self.artist = artist
        self.album = album; self.coverArt = coverArt; self.duration = duration
    }
}

/// One registered client — iPhone / iPad / Mac / Web.
public struct Device: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let kind: String       // "iphone" | "ipad" | "mac" | "web" | "other"
    public let isPlaying: Bool
    public let currentSong: DeviceSong?
    public let position: Double
    public let duration: Double
    public let last_seen: Double

    public static func == (l: Device, r: Device) -> Bool { l.id == r.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Payload sent up by every client on init + every ~15s.
public struct DeviceHeartbeat: Codable, Sendable {
    public var id: String?          // nil on first call — server assigns
    public var name: String
    public var kind: String
    public var isPlaying: Bool
    public var currentSong: DeviceSong?
    public var position: Double
    public var duration: Double
    public init(id: String?, name: String, kind: String, isPlaying: Bool,
                currentSong: DeviceSong?, position: Double, duration: Double) {
        self.id = id; self.name = name; self.kind = kind
        self.isPlaying = isPlaying; self.currentSong = currentSong
        self.position = position; self.duration = duration
    }
}

/// A play/pause command queued by another device.
public struct DeviceCommand: Codable, Sendable {
    public let type: String       // "play" | "pause"
    public let song: DeviceSong?
    public let position: Double?
}

/// Progress for a save-to-library download started via ``SubsonicClient/startSave(youtubeId:folder:)``.
public struct DownloadStatus: Sendable, Codable {
    /// `queued` → `sourcing` → `downloading` or `saving-youtube` → `done` / `failed`.
    public let state: String
    public let percent: Int
    public let detail: String
    public var isTerminal: Bool { state == "done" || state == "failed" }
}

public enum SubsonicClientError: Error, Sendable {
    case badStatus(Int)
    case notOK(String)
}
