// App-target file. Playlist detail — its songs.
import SwiftUI
import GeetHubKit

struct PlaylistDetailView: View {
    @Environment(Session.self) private var session
    @Environment(PlayerEngine.self) private var player
    @Environment(PlaylistFavorites.self) private var playlistFavs
    let playlist: Playlist

    @State private var songs: [Song] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Rectangle().fill(Theme.surface).frame(width: 180, height: 180)
                    .overlay(Rectangle().strokeBorder(Theme.hairline, lineWidth: 1))
                    .overlay(Image(systemName: "music.note.list").font(.system(size: 56)).foregroundStyle(Theme.graphite))
                    .padding(.top, 8)
                Text(playlist.name).retro(22, .semibold, tracking: 1).multilineTextAlignment(.center)

                Button { player.play(songs, startAt: 0) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text("Play").retro(14, .semibold, color: .white, tracking: 2)
                    }
                    .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Theme.accent)
                }
                .disabled(songs.isEmpty).padding(.horizontal, 40)

                SongList(songs: songs).padding(.bottom, 120)
            }
        }
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Text(playlist.name).retro(12, .medium, tracking: 2).lineLimit(1) }
            ToolbarItem(placement: .topBarTrailing) {
                Button { playlistFavs.toggle(playlist.id) } label: {
                    Image(systemName: playlistFavs.isFavorite(playlist.id) ? "heart.fill" : "heart")
                        .foregroundStyle(playlistFavs.isFavorite(playlist.id) ? Theme.accent : Theme.ink)
                }
            }
        }
        .overlay { if isLoading { ProgressView() } }
        .task {
            songs = (try? await session.client?.playlist(id: playlist.id))?.entry ?? []
            isLoading = false
        }
    }
}
