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
