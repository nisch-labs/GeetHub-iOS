// App-target file. Home — greeting, compact curated cards, then Recently Played,
// Favourites, Recently Added, and Most Listened sections.
import SwiftUI
import GeetHubKit

struct HomeView: View {
    @Environment(Session.self) private var session
    @Environment(PlayerEngine.self) private var player
    var onSelectTab: (Int) -> Void = { _ in }

    @State private var newest: [Album] = []
    @State private var frequent: [Album] = []
    @State private var recent: [Album] = []
    @State private var favorites: [Song] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    header
                    curated
                    if !recent.isEmpty { albumGridSection("Recently Played", recent) }
                    if !favorites.isEmpty { favouritesSection }
                    if !newest.isEmpty { albumGridSection("Recently Added", newest) }
                    if !frequent.isEmpty { mostListenedSection }
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

    // MARK: - Curated (compact cards)

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

    // MARK: - Album grid section (Recently Played / Recently Added)

    private func albumGridSection(_ title: String, _ albums: [Album]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeaderLink(title: title) { AlbumGridScreen(title: title, albums: albums) }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(albums.prefix(4)) { AlbumMiniCard(album: $0) }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Favourites (horizontal play cards)

    private var favouritesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeaderLink(title: "Favourites") { SongsScreen(title: "Favourites", songs: favorites) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(Array(favorites.prefix(10).enumerated()), id: \.element.id) { index, song in
                        Button { player.play(favorites, startAt: index) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ArtworkImage(coverArt: song.coverArt, size: 150, shape: .sleeve, corner: 14)
                                Text(song.title).retro(12, .semibold).lineLimit(1).frame(width: 150, alignment: .leading)
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

    // MARK: - Most Listened (list rows)

    private var mostListenedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeaderLink(title: "Most Listened") { AlbumGridScreen(title: "Most Listened", albums: frequent) }
            LazyVStack(spacing: 16) {
                ForEach(frequent.prefix(5)) { album in
                    AlbumRow(album: album)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Data / actions

    private func load() async {
        guard let client = session.client else { return }
        async let n = client.albumList(type: "newest", size: 20)
        async let f = client.albumList(type: "frequent", size: 20)
        async let r = client.albumList(type: "recent", size: 20)
        async let fav = client.favorites()
        newest = (try? await n) ?? []
        frequent = (try? await f) ?? []
        recent = (try? await r) ?? []
        favorites = (try? await fav)?.song ?? []
        isLoading = false
    }

    private func shuffleAll() async {
        guard let c = session.client, let songs = try? await c.randomSongs(count: 100), !songs.isEmpty else { return }
        player.play(songs, startAt: 0)
    }
    private func playRandomAlbum() async {
        guard let album = recent.randomElement() ?? newest.randomElement() ?? frequent.randomElement() else { return }
        await playAlbum(album)
    }
    private func playAlbum(_ album: Album) async {
        guard let c = session.client, let songs = try? await c.album(id: album.id)?.song, !songs.isEmpty else { return }
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

/// Horizontal mini album card (thumb + artist + title) for 2-column grids.
private struct AlbumMiniCard: View {
    let album: Album

    var body: some View {
        NavigationLink(value: album) {
            HStack(spacing: 10) {
                ArtworkImage(coverArt: album.coverArt, size: 50, shape: .sleeve, corner: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(album.artist ?? "").retro(9, .light, color: Theme.graphite, tracking: 1).lineLimit(1)
                    Text(album.name).retro(12, .semibold).lineLimit(1)
                }
                Spacer(minLength: 2)
            }
            .padding(8)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Tappable album row (Most Listened) — opens the album.
struct AlbumRow: View {
    let album: Album

    var body: some View {
        NavigationLink(value: album) {
            HStack(spacing: 14) {
                ArtworkImage(coverArt: album.coverArt, size: 56, shape: .sleeve, corner: 12)
                VStack(alignment: .leading, spacing: 3) {
                    Text(album.artist ?? "Unknown").retro(9, .light, color: Theme.graphite, tracking: 1).lineLimit(1)
                    Text(album.name).retro(14, .semibold).lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Theme.graphite)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
