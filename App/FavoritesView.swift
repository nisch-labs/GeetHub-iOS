// App-target file. Favorites — starred songs (+ favorite albums shelf).
import SwiftUI
import GeetHubKit

struct FavoritesView: View {
    @Environment(Session.self) private var session
    @Environment(PlayerEngine.self) private var player

    @State private var songs: [Song] = []
    @State private var albums: [Album] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Favourites").retro(20, .bold, tracking: 1)
                        Spacer()
                        if !songs.isEmpty {
                            HStack(spacing: 18) {
                                Button { player.playShuffled(songs) } label: {
                                    Image(systemName: "shuffle").font(.footnote).foregroundStyle(Theme.accent)
                                }
                                Button { player.play(songs, startAt: 0) } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "play.fill").font(.footnote)
                                        Text("Play").retro(12, .semibold, color: Theme.accent, tracking: 1.5)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 8)

                    if !albums.isEmpty {
                        AlbumShelf(title: "Albums", albums: albums)
                    }

                    if !songs.isEmpty {
                        SectionHeader(title: "Songs")
                        SongList(songs: songs)
                    } else if !isLoading {
                        ContentUnavailableView("No favorites yet",
                            systemImage: "heart",
                            description: Text("Tap the heart on a song to save it here."))
                            .padding(.top, 40)
                    }
                }
                .padding(.bottom, 120)
            }
            .paperBackground()
            .navigationBarHidden(true)
            .navigationDestination(for: Album.self) { AlbumDetailView(album: $0) }
            .refreshable { await load() }
            .overlay { if isLoading { ProgressView() } }
        }
        .task { await load() }
    }

    private func load() async {
        guard let client = session.client else { return }
        let fav = try? await client.favorites()
        songs = fav?.song ?? []
        albums = fav?.album ?? []
        isLoading = false
    }
}
