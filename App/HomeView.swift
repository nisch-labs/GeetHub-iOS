// App-target file. Home v2 — greeting, filter chips, featured hero, playlists,
// and album shelves. Reference layout, rendered in the vinyl/retro system.
import SwiftUI
import GeetHubKit

struct HomeView: View {
    @Environment(Session.self) private var session
    @Environment(PlayerEngine.self) private var player

    @State private var newest: [Album] = []
    @State private var frequent: [Album] = []
    @State private var recent: [Album] = []
    @State private var playlists: [Playlist] = []
    @State private var genres: [Genre] = []
    @State private var filter = 0            // 0 Recently Added · 1 Most Played · 2 Recently Played · 3 Mixes
    @State private var isLoading = true

    private let filters = ["Recently Added", "Most Played", "Recently Played", "Mixes"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    greeting
                    chips
                    featured
                    primarySection
                    playlistsSection
                }
                .padding(.top, 8)
                .padding(.bottom, 130)
            }
            .paperBackground()
            .navigationBarHidden(true)
            .navigationDestination(for: Album.self) { AlbumDetailView(album: $0) }
            .navigationDestination(for: Playlist.self) { PlaylistDetailView(playlist: $0) }
            .overlay { if isLoading { ProgressView() } }
        }
        .task { await load() }
    }

    // MARK: - Header

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle().fill(Theme.surface).frame(width: 44, height: 44)
                    .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                    .overlay(Image(systemName: "opticaldisc").foregroundStyle(Theme.teal))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Geet-Hub · On the turntable")
                        .retro(9, .light, color: Theme.graphite, tracking: 2)
                    Text(timeGreeting).retro(13, .medium, tracking: 2)
                }
                Spacer()
            }
            Text((session.client?.credentials.username ?? "friend"))
                .retro(34, .bold, tracking: 1)
        }
        .padding(.horizontal, 20)
    }

    private var timeGreeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Late night"
        }
    }

    // MARK: - Chips

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(filters.enumerated()), id: \.offset) { index, title in
                    Button { filter = index } label: { Chip(title: title, filled: filter == index) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Featured

    private var featured: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Discover")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    FeaturedCard(title: "Shuffle", subtitle: "A fresh mix from everything", filled: true) {
                        Task { await shuffleAll() }
                    }
                    FeaturedCard(title: "Rediscover", subtitle: "A random album, start to finish", filled: false) {
                        Task { await playRandomAlbum() }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Primary section (driven by the chips)

    @ViewBuilder private var primarySection: some View {
        switch filter {
        case 1: AlbumShelf(title: "Most Played", albums: frequent)
        case 2: AlbumShelf(title: "Recently Played", albums: recent)
        case 3: mixes
        default: AlbumShelf(title: "Recently Added", albums: newest)
        }
    }

    private var mixes: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Mixes")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(genres.prefix(14)) { genre in
                        Button { Task { await playGenre(genre.name) } } label: { Chip(title: genre.name) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Playlists

    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Your Playlists", trailing: playlists.isEmpty ? nil : "\(playlists.count)")
            LazyVStack(spacing: 0) {
                ForEach(playlists.prefix(8)) { playlist in
                    HStack(spacing: 12) {
                        NavigationLink(value: playlist) {
                            HStack(spacing: 12) {
                                Rectangle().fill(Theme.surface).frame(width: 46, height: 46)
                                    .overlay(Rectangle().strokeBorder(Theme.hairline, lineWidth: 1))
                                    .overlay(Image(systemName: "music.note.list").foregroundStyle(Theme.graphite))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(playlist.name).retro(14, .medium).lineLimit(1)
                                    Text("\(playlist.songCount ?? 0) songs")
                                        .retro(9, .light, color: Theme.graphite, tracking: 1)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Button { Task { await playPlaylist(playlist) } } label: {
                            Image(systemName: "play.circle").font(.title2).foregroundStyle(Theme.teal)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 8)
                    Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 78)
                }
            }
        }
    }

    // MARK: - Data / actions

    private func load() async {
        guard let client = session.client else { return }
        async let n = client.albumList(type: "newest", size: 20)
        async let f = client.albumList(type: "frequent", size: 20)
        async let r = client.albumList(type: "recent", size: 20)
        async let p = client.playlists()
        async let g = client.genres()
        newest = (try? await n) ?? []
        frequent = (try? await f) ?? []
        recent = (try? await r) ?? []
        playlists = (try? await p) ?? []
        genres = (try? await g) ?? []
        isLoading = false
    }

    private func shuffleAll() async {
        guard let c = session.client, let songs = try? await c.randomSongs(count: 100), !songs.isEmpty else { return }
        player.play(songs, startAt: 0)
    }

    private func playRandomAlbum() async {
        guard let c = session.client, let album = newest.randomElement() ?? frequent.randomElement(),
              let songs = try? await c.album(id: album.id)?.song, !songs.isEmpty else { return }
        player.play(songs, startAt: 0)
    }

    private func playGenre(_ name: String) async {
        guard let c = session.client, let songs = try? await c.songsByGenre(name, count: 100), !songs.isEmpty else { return }
        player.play(songs, startAt: 0)
    }

    private func playPlaylist(_ playlist: Playlist) async {
        guard let c = session.client, let songs = try? await c.playlist(id: playlist.id)?.entry, !songs.isEmpty else { return }
        player.play(songs, startAt: 0)
    }
}

/// Big featured action card.
struct FeaturedCard: View {
    let title: String
    let subtitle: String
    let filled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: filled ? "shuffle" : "opticaldisc")
                    .font(.title2)
                    .foregroundStyle(filled ? .white : Theme.teal)
                Spacer(minLength: 0)
                Text(title).retro(22, .bold, color: filled ? .white : Theme.ink, tracking: 1)
                Text(subtitle)
                    .retro(10, .regular, color: filled ? .white.opacity(0.9) : Theme.graphite, tracking: 1)
                    .lineLimit(2)
                HStack {
                    Spacer()
                    Image(systemName: "play.fill").foregroundStyle(filled ? .white : Theme.teal)
                }
            }
            .padding(18)
            .frame(width: 260, height: 150, alignment: .leading)
            .background(filled ? Theme.teal : Theme.surface)
            .overlay(Rectangle().strokeBorder(filled ? .clear : Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
