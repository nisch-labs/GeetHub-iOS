import Testing
import Foundation
@testable import GeetHubKit

@Test func tokenMatchesSubsonicSpec() {
    // Known Subsonic example: password "sesame", salt "c19b2d" -> md5 below.
    let token = SubsonicCredentials.token(password: "sesame", salt: "c19b2d")
    #expect(token == "26719a1196d2a940705a59634eb18eab")
}

@Test func authQueryItemsIncludeTokenAndSalt() {
    let creds = SubsonicCredentials(
        baseURL: URL(string: "http://100.75.88.86:4544")!,
        username: "nischdev", password: "pw"
    )
    let items = creds.authQueryItems(salt: "abc123")
    let dict = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value) })
    #expect(dict["u"] == "nischdev")
    #expect(dict["s"] == "abc123")
    #expect(dict["t"] == SubsonicCredentials.token(password: "pw", salt: "abc123"))
    #expect(dict["f"] == "json")
    #expect(dict["c"] == "GeetHub")
}

@Test func streamURLBuildsRestPath() {
    let creds = SubsonicCredentials(
        baseURL: URL(string: "http://100.75.88.86:4544")!,
        username: "u", password: "p"
    )
    let client = SubsonicClient(credentials: creds)
    let url = client.streamURL(id: "yt-abc")
    #expect(url.absoluteString.contains("/rest/stream.view"))
    #expect(url.absoluteString.contains("id=yt-abc"))
}

// MARK: - Login / Session

@Test func credentialsRoundTripThroughInMemoryStore() throws {
    let store = InMemoryCredentialStore()
    let creds = SubsonicCredentials(
        baseURL: URL(string: "http://100.75.88.86:4544")!,
        username: "nischdev", password: "secret")
    try store.save(creds)
    #expect(try store.load() == creds)
    try store.clear()
    #expect(try store.load() == nil)
}

@Test func urlNormalizationAddsSchemeAndTrimsSlash() {
    #expect(Session.normalizeURL("100.75.88.86:4544")?.absoluteString == "http://100.75.88.86:4544")
    #expect(Session.normalizeURL("https://music.nixsocket.com/")?.absoluteString == "https://music.nixsocket.com")
    #expect(Session.normalizeURL("   ") == nil)
    #expect(Session.normalizeURL("not a url with spaces") == nil)
}

@Test @MainActor func sessionRestoresSavedServer() {
    let creds = SubsonicCredentials(
        baseURL: URL(string: "http://host:4544")!, username: "u", password: "p")
    let session = Session(store: InMemoryCredentialStore(creds))
    #expect(session.state == .signedOut)
    session.restore()
    #expect(session.isConnected)
    #expect(session.client?.credentials.username == "u")
    session.signOut()
    #expect(session.state == .signedOut)
    #expect(session.client == nil)
}

// MARK: - PlaybackQueue

private func makeSongs(_ n: Int) -> [Song] {
    (1...n).map { i in
        try! JSONDecoder().decode(Song.self, from: Data(
            "{\"id\":\"s\(i)\",\"title\":\"Song \(i)\"}".utf8))
    }
}

@Test func queueLoadAndBasicNextPrev() {
    var q = PlaybackQueue()
    q.load(makeSongs(3), startAt: 0)
    #expect(q.current?.id == "s1")
    #expect(q.upNext.map(\.id) == ["s2", "s3"])
    #expect(q.next()?.id == "s2")
    #expect(q.next()?.id == "s3")
    #expect(q.next() == nil || q.current?.id == "s3")  // end, repeat off
    #expect(q.previous()?.id == "s2")
}

@Test func queueRepeatAllWraps() {
    var q = PlaybackQueue()
    q.load(makeSongs(2), startAt: 1)
    q.repeatMode = .all
    #expect(q.current?.id == "s2")
    #expect(q.next()?.id == "s1")            // wrapped
    #expect(q.previous()?.id == "s2")        // wrapped back
}

@Test func queueRepeatOneReplaysOnAuto() {
    var q = PlaybackQueue()
    q.load(makeSongs(3), startAt: 0)
    q.repeatMode = .one
    #expect(q.next(auto: true)?.id == "s1")  // natural end repeats same track
    #expect(q.next(auto: false)?.id == "s2") // user skip still advances
}

@Test func queueShufflePreservesCurrentAndAllItems() {
    var q = PlaybackQueue()
    q.load(makeSongs(5), startAt: 2)
    #expect(q.current?.id == "s3")
    q.setShuffled(true)
    #expect(q.isShuffled)
    #expect(q.current?.id == "s3")           // still playing the same track
    // Every item still reachable exactly once.
    let ids = Set([q.current!.id] + q.upNext.map(\.id))
    #expect(ids == Set(["s1", "s2", "s3", "s4", "s5"]))
    q.setShuffled(false)
    #expect(q.current?.id == "s3")           // restored, still on same track
}

@Test func queuePlayNextInsertsAfterCurrent() {
    var q = PlaybackQueue()
    q.load(makeSongs(3), startAt: 0)
    let extra = makeSongs(1)[0]              // "s1" id clashes; make a distinct one
    let injected = try! JSONDecoder().decode(Song.self, from: Data(
        "{\"id\":\"x9\",\"title\":\"Injected\"}".utf8))
    q.playNext(injected)
    _ = extra
    #expect(q.upNext.first?.id == "x9")
    #expect(q.next()?.id == "x9")
}

@Test func queueRemoveKeepsCurrentSensible() {
    var q = PlaybackQueue()
    q.load(makeSongs(4), startAt: 2)         // playing s3
    q.remove(atOrderPosition: 0)             // remove s1 (before current)
    #expect(q.current?.id == "s3")           // still on s3
    #expect(q.count == 3)
}

@Test func decodesSearchResult3WithYouTubeTrack() throws {
    let json = """
    {"subsonic-response":{"status":"ok","version":"1.16.1","searchResult3":{
      "song":[
        {"id":"real1","title":"The Cave","artist":"Mumford & Sons","suffix":"flac"},
        {"id":"yt-abc","title":"Mykonos","artist":"Fleet Foxes","album":"YouTube","size":7328000,"suffix":"mp3"}
      ]}}}
    """
    let resp = try JSONDecoder().decode(SubsonicEnvelope.self, from: Data(json.utf8)).subsonicResponse
    let songs = try #require(resp.searchResult3?.song)
    #expect(songs.count == 2)
    #expect(songs[1].isYouTube)
    #expect(songs[0].isYouTube == false)
    #expect(songs[1].size == 7328000)
}
