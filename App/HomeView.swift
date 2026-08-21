// App-target file. Home — shuffle, genre mixes, recently added / played.
import SwiftUI
import GeetHubKit

struct HomeView: View {
    @Environment(Session.self) private var session
    @Environment(PlayerEngine.self) private var player

    @State private var newest: [Album] = []
    @State private var recent: [Album] = []
    @State private var genres: [Genre] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    header
                    shuffleHero
                    tunedIn
                    AlbumShelf(title: "Recently Added", albums: newest)
                    AlbumShelf(title: "Recently Played", albums: recent)
                }
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .paperBackground()
            .navigationBarHidden(true)
            .navigationDestination(for: Album.self) { AlbumDetailView(album: $0) }
            .overlay { if isLoading { ProgressView() } }
        }
        .task { await load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Geet-Hub").retro(30, .bold, tracking: 2)
            Text("On the turntable").retro(10, .light, color: Theme.graphite, tracking: 3)
        }
        .padding(.horizontal, 20)
    }

    private var shuffleHero: some View {
        Button { Task { await shuffleAll() } } label: {
            HStack(spacing: 12) {
                Image(systemName: "shuffle")
                Text("Shuffle Everything").retro(15, .semibold, color: .white, tracking: 2)
                Spacer()
                Image(systemName: "play.fill")
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20).padding(.vertical, 18)
            .background(Theme.teal)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    private var tunedIn: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Tuned In")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Button { Task { await shuffleAll() } } label: { Chip(title: "Mix It Up", filled: true) }
                        .buttonStyle(.plain)
                    ForEach(genres.prefix(12)) { genre in
                        Button { Task { await playGenre(genre.name) } } label: { Chip(title: genre.name) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Data / actions

    private func load() async {
        guard let client = session.client else { return }
        async let newestA = client.albumList(type: "newest", size: 20)
        async let recentA = client.albumList(type: "recent", size: 20)
        async let genresA = client.genres()
        newest = (try? await newestA) ?? []
        recent = (try? await recentA) ?? []
        genres = (try? await genresA) ?? []
        isLoading = false
    }

    private func shuffleAll() async {
        guard let client = session.client,
              let songs = try? await client.randomSongs(count: 100), !songs.isEmpty else { return }
        player.play(songs, startAt: 0)
    }

    private func playGenre(_ name: String) async {
        guard let client = session.client,
              let songs = try? await client.songsByGenre(name, count: 100), !songs.isEmpty else { return }
        player.play(songs, startAt: 0)
    }
}
