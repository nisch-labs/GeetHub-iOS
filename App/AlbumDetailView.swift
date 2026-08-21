// App-target file. Album detail — sleeve, play, tracklist.
import SwiftUI
import GeetHubKit

struct AlbumDetailView: View {
    @Environment(Session.self) private var session
    @Environment(PlayerEngine.self) private var player
    let album: Album

    @State private var songs: [Song] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ArtworkImage(coverArt: album.coverArt, size: 220, shape: .sleeve)
                    .shadow(color: .black.opacity(0.1), radius: 16, y: 8)
                    .padding(.top, 8)

                VStack(spacing: 6) {
                    Text(album.name).retro(22, .semibold, tracking: 1).multilineTextAlignment(.center)
                    Text(album.artist ?? "").retro(12, .light, color: Theme.graphite, tracking: 2)
                }

                Button { player.play(songs, startAt: 0) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text("Play").retro(14, .semibold, color: .white, tracking: 2)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Theme.teal)
                }
                .disabled(songs.isEmpty)
                .padding(.horizontal, 40)

                LazyVStack(spacing: 0) {
                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                        HStack(spacing: 0) {
                            Button { player.play(songs, startAt: index) } label: {
                                HStack(spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.system(.footnote, design: .monospaced))
                                        .foregroundStyle(Theme.graphite).frame(width: 24)
                                    SongRow(song: song, isPlaying: player.current?.id == song.id,
                                            favorited: player.isFavorite(song))
                                }
                                .padding(.leading, 20).padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .songContextMenu(song)
                            SongMenuButton(song: song).padding(.trailing, 12)
                        }
                        Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 56)
                    }
                }
                .padding(.bottom, 120)
            }
        }
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(album.name).retro(12, .medium, tracking: 2).lineLimit(1)
            }
        }
        .overlay { if isLoading { ProgressView() } }
        .task { await load() }
    }

    private func load() async {
        guard let client = session.client else { return }
        songs = (try? await client.album(id: album.id))?.song ?? []
        isLoading = false
    }
}
