// App-target file. Album detail — song list + play.
import SwiftUI
import GeetHubKit

struct AlbumDetailView: View {
    @Environment(Session.self) private var session
    @Environment(PlayerEngine.self) private var player
    let album: Album

    @State private var songs: [Song] = []
    @State private var isLoading = true

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    ArtworkImage(coverArt: album.coverArt, size: 100)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(album.name).font(.title3.bold()).lineLimit(2)
                        Text(album.artist ?? "").foregroundStyle(.secondary)
                        if let n = album.songCount { Text("\(n) songs").font(.caption).foregroundStyle(.secondary) }
                    }
                }
                Button {
                    player.play(songs, startAt: 0)
                } label: {
                    Label("Play", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(songs.isEmpty)
            }

            Section {
                ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                    Button {
                        player.play(songs, startAt: index)
                    } label: {
                        SongRow(song: song, isPlaying: player.current?.id == song.id)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(album.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .overlay { if isLoading { ProgressView() } }
    }

    private func load() async {
        guard let client = session.client else { return }
        songs = (try? await client.album(id: album.id))?.song ?? []
        isLoading = false
    }
}
