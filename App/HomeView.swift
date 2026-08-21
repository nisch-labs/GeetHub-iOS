// App-target file. Home — greeting, curated cards, then Recently Played,
// Favourites, Recently Added (song shelves) and Most Listened (song list).
import SwiftUI
import GeetHubKit

struct HomeView: View {
    @Environment(Session.self) private var session
    @Environment(PlayerEngine.self) private var player
    var onSelectTab: (Int) -> Void = { _ in }

    @State private var recentlyAdded: [Song] = []
    @State private var mostListened: [Song] = []
    @State private var favorites: [Song] = []
    @State private var albumsForRediscover: [Album] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    header
                    curated
                    if !player.recentlyPlayed.isEmpty { songShelf("Recently Played", player.recentlyPlayed) }
                    if !favorites.isEmpty { songShelf("Favourites", favorites) }
                    if !recentlyAdded.isEmpty { songShelf("Recently Added", recentlyAdded) }
                    if !mostListened.isEmpty { mostListenedSection }
                }
                .padding(.top, 12)
                .padding(.bottom, 140)
            }
            .paperBackground()
            .navigationBarHidden(true)
            .navigationDestination(for: Album.self) { AlbumDetailView(album: $0) }
            .refreshable { await load() }
            .overlay { if isLoading { ProgressView() } }
        }
        .task { await load() }
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
            roundButton("gearshape") { onSelectTab(4) }
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
            SectionHeader(title: "Curated for you")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    CompactCard(title: "Discover", subtitle: "A fresh shuffle", filled: false, icon: "shuffle") {
                        Task { await shuffleAll() }
                    }
                    CompactCard(title: "Rediscover", subtitle: "A random album", filled: false, icon: "opticaldisc") {
                        Task { await playRandomAlbum() }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Song shelf (horizontal)

    private func songShelf(_ title: String, _ songs: [Song]) -> some View {
        let items = Array(songs.prefix(20))
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeaderLink(title: title) { SongsScreen(title: title, songs: songs) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, song in
                        Button { player.play(items, startAt: index) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ArtworkImage(coverArt: song.coverArt, size: 150, shape: .sleeve, corner: 14)
                                Text(song.title).retro(12, .semibold).lineLimit(1)
                                    .frame(width: 150, alignment: .leading)
                                Text(song.artist ?? "").retro(9, .light, color: Theme.graphite, tracking: 1)
                                    .lineLimit(1).frame(width: 150, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
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
        async let songsA = client.allSongs(size: 300)
        async let favA = client.favorites()
        async let albumsA = client.albumList(type: "newest", size: 20)
        let all = (try? await songsA) ?? []
        recentlyAdded = all.sorted { ($0.created ?? "") > ($1.created ?? "") }
        mostListened = all.filter { ($0.playCount ?? 0) > 0 }
            .sorted { ($0.playCount ?? 0) > ($1.playCount ?? 0) }
        favorites = (try? await favA)?.song ?? []
        albumsForRediscover = (try? await albumsA) ?? []
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
}

// MARK: - Home components

/// Compact curated card (small, like a tab).
private struct CompactCard: View {
    let title: String
    let subtitle: String
    let filled: Bool
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 18))
                    .foregroundStyle(filled ? .white : Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).retro(15, .bold, color: filled ? .white : Theme.ink, tracking: 0.5)
                    Text(subtitle).retro(9, .regular, color: filled ? .white.opacity(0.9) : Theme.graphite, tracking: 0.5)
                }
                Spacer(minLength: 8)
                Image(systemName: "play.fill").font(.system(size: 12))
                    .foregroundStyle(filled ? .white : Theme.accent)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .frame(width: 230)
            .background(filled ? Theme.accent : Theme.surface,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(filled ? .clear : Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
