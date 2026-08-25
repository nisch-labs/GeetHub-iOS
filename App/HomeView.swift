// App-target file. Home — greeting, curated cards, then Recently Played,
// Favourites, Recently Added (song shelves) and Most Listened (song list).
import SwiftUI
import GeetHubKit

struct HomeView: View {
    @Environment(Session.self) private var session
    @Environment(PlayerEngine.self) private var player
    @Environment(PlaylistFavorites.self) private var playlistFavs
    var onSelectTab: (Int) -> Void = { _ in }

    @State private var recentlyAdded: [Song] = []
    @State private var mostListened: [Song] = []
    @State private var favorites: [Song] = []
    @State private var albumsForRediscover: [Album] = []
    @State private var allPlaylists: [Playlist] = []
    @State private var isLoading = true

    private var favouritePlaylists: [Playlist] { allPlaylists.filter { playlistFavs.isFavorite($0.id) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    header
                    curated
                    if !favorites.isEmpty { songShelf("Favourites", favorites, size: 150) }
                    if !favouritePlaylists.isEmpty { playlistShelf }
                    if !player.recentlyPlayed.isEmpty { songShelf("Recently Played", player.recentlyPlayed, size: 92) }
                    if !recentlyAdded.isEmpty { songShelf("Recently Added", recentlyAdded, size: 92) }
                    if !mostListened.isEmpty { mostListenedSection }
                }
                .padding(.top, 12)
                .padding(.bottom, 140)
            }
            .paperBackground()
            .navigationBarHidden(true)
            .navigationDestination(for: Album.self) { AlbumDetailView(album: $0) }
            .navigationDestination(for: Playlist.self) { PlaylistDetailView(playlist: $0) }
            .refreshable { await load() }
            .overlay { if isLoading { ProgressView() } }
        }
        .task { await load() }
        // A save just completed — give Navidrome a couple of seconds to scan,
        // then refresh so the new song appears in "Recently Added".
        .onChange(of: player.savedYouTube.count) { _, _ in
            Task {
                try? await Task.sleep(for: .seconds(3))
                await load()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timeGreeting).retro(11, .light, color: Theme.graphite, tracking: 1.5)
                Text(session.client?.credentials.username ?? "friend").retro(20, .bold, tracking: 1)
            }
            Spacer()
            roundButton("magnifyingglass") { onSelectTab(3) }
        }
        .padding(.horizontal, 20)
    }

    private func roundButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(Theme.ink)
                .frame(width: 42, height: 42)
                .background(Theme.surface, in: Circle())
                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
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

    // MARK: - Curated

    private var curated: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Smart Play")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)],
                      spacing: 10) {
                CompactCard(title: "Discover", subtitle: "Fresh shuffle", icon: "shuffle") {
                    Task { await shuffleAll() }
                }
                CompactCard(title: "Rediscover", subtitle: "Random album", icon: "opticaldisc") {
                    Task { await playRandomAlbum() }
                }
                CompactCard(title: "On Repeat", subtitle: "Top plays", icon: "flame") {
                    Task { await playOnRepeat() }
                }
                CompactCard(title: "Deep Cuts", subtitle: "Never played", icon: "sparkles") {
                    Task { await playDeepCuts() }
                }
                CompactCard(title: "Favourites", subtitle: "Shuffle stars", icon: "heart.fill") {
                    Task { await playFavouritesMix() }
                }
                CompactCard(title: "Roulette", subtitle: "Random playlist", icon: "music.note.list") {
                    Task { await playRandomPlaylist() }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Song shelf (horizontal)

    private func songShelf(_ title: String, _ songs: [Song], size: CGFloat = 150) -> some View {
        let items = Array(songs.prefix(20))
        let small = size < 120
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeaderLink(title: title) { SongsScreen(title: title, songs: songs) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: small ? 12 : 16) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, song in
                        Button { player.play(items, startAt: index) } label: {
                            VStack(alignment: .leading, spacing: small ? 6 : 8) {
                                ArtworkImage(coverArt: song.coverArt, size: size, shape: .sleeve, corner: small ? 10 : 14)
                                    .overlay(alignment: .topLeading) {
                                        if let src = song.virtualSource, !player.savedYouTube.contains(song.id) {
                                            SourceTag(source: src).padding(6)
                                        }
                                    }
                                Text(song.title).retro(small ? 10 : 12, .semibold).lineLimit(1)
                                    .frame(width: size, alignment: .leading)
                                Text(song.artist ?? "").retro(small ? 8 : 9, .light, color: Theme.graphite, tracking: 1)
                                    .lineLimit(1).frame(width: size, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Favourite Playlists (small cards)

    private var playlistShelf: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Favourite Playlists")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(favouritePlaylists) { playlist in
                        NavigationLink(value: playlist) {
                            VStack(alignment: .leading, spacing: 6) {
                                playlistArt(playlist, size: 92)
                                Text(playlist.name).retro(10, .semibold).lineLimit(1)
                                    .frame(width: 92, alignment: .leading)
                                Text("\(playlist.songCount ?? 0) songs")
                                    .retro(8, .light, color: Theme.graphite, tracking: 1).lineLimit(1)
                                    .frame(width: 92, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    @ViewBuilder private func playlistArt(_ playlist: Playlist, size: CGFloat) -> some View {
        if let art = playlist.coverArt {
            ArtworkImage(coverArt: art, size: size, shape: .sleeve, corner: 10)
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.surface)
                .frame(width: size, height: size)
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
                .overlay(Image(systemName: "music.note.list").font(.system(size: size * 0.3)).foregroundStyle(Theme.graphite))
        }
    }

    // MARK: - Most Listened (song list)

    private var mostListenedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeaderLink(title: "Most Listened") { SongsScreen(title: "Most Listened", songs: mostListened) }
            SongList(songs: Array(mostListened.prefix(6)))
        }
    }

    // MARK: - Data / actions

    private func load() async {
        guard let client = session.client else { return }
        async let songsA = client.allSongs(size: 500)
        async let favA = client.favorites()
        async let albumsA = client.albumList(type: "newest", size: 20)
        async let plA = client.playlists()
        let all = (try? await songsA) ?? []
        mostListened = all.filter { ($0.playCount ?? 0) > 0 }
            .sorted { ($0.playCount ?? 0) > ($1.playCount ?? 0) }
        favorites = (try? await favA)?.song ?? []
        let newestAlbums = (try? await albumsA) ?? []
        albumsForRediscover = newestAlbums
        allPlaylists = (try? await plA) ?? []
        // "Recently Added" from the newest N albums (reliable regardless of
        // library size) — expand each to its songs and sort by song `created`.
        // `allSongs(size:)` returns whatever server order and would truncate
        // freshly-added tracks out of the window on a large library.
        let expanded = await withTaskGroup(of: [Song].self) { group in
            for album in newestAlbums.prefix(15) {
                group.addTask { (try? await client.album(id: album.id))?.song ?? [] }
            }
            var acc: [Song] = []
            for await songs in group { acc.append(contentsOf: songs) }
            return acc
        }
        recentlyAdded = expanded.sorted { ($0.created ?? "") > ($1.created ?? "") }
        #if DEBUG
        if ProcessInfo.processInfo.environment["GEETHUB_SEEDPLFAV"] == "1" {
            for p in allPlaylists.prefix(4) where !playlistFavs.isFavorite(p.id) { playlistFavs.toggle(p.id) }
        }
        #endif
        isLoading = false
    }

    private func shuffleAll() async {
        guard let c = session.client, let songs = try? await c.randomSongs(count: 100), !songs.isEmpty else { return }
        player.play(songs, startAt: 0)
    }
    private func playRandomAlbum() async {
        guard let c = session.client, let album = albumsForRediscover.randomElement(),
              let songs = try? await c.album(id: album.id)?.song, !songs.isEmpty else { return }
        player.play(songs, startAt: 0)
    }
    private func playOnRepeat() async {
        // mostListened is already sorted by playCount desc when Home loads.
        // Take the top 50 and shuffle client-side for variety within top plays.
        let top = Array(mostListened.prefix(50)).shuffled()
        guard !top.isEmpty else { return }
        player.play(top, startAt: 0)
    }
    private func playDeepCuts() async {
        // Songs the user has never played — from the same allSongs(500) page.
        // Best-effort: on very large libraries this may miss unloved tracks
        // outside the page. Good enough for a serendipity button.
        guard let c = session.client else { return }
        let all = (try? await c.allSongs(size: 500)) ?? []
        let unplayed = all.filter { ($0.playCount ?? 0) == 0 }.shuffled()
        guard !unplayed.isEmpty else { return }
        player.play(Array(unplayed.prefix(50)), startAt: 0)
    }
    private func playFavouritesMix() async {
        // Reuse the favourites already loaded on Home; refresh in case the
        // user has starred more since load.
        guard let c = session.client else { return }
        let fresh = (try? await c.favorites())?.song ?? favorites
        let mixed = fresh.shuffled()
        guard !mixed.isEmpty else { return }
        player.play(mixed, startAt: 0)
    }
    private func playRandomPlaylist() async {
        guard let c = session.client,
              let pl = allPlaylists.randomElement(),
              let songs = try? await c.playlist(id: pl.id)?.entry, !songs.isEmpty else { return }
        player.play(songs, startAt: 0)
    }
}

// MARK: - Home components

/// Compact tile used in the Smart Play 3-column grid on Home.
private struct CompactCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 16))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).retro(11, .bold, color: Theme.ink, tracking: 0.5)
                        .lineLimit(1).minimumScaleFactor(0.75)
                    Text(subtitle).retro(8, .regular, color: Theme.graphite, tracking: 0.5)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10).padding(.vertical, 10)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
