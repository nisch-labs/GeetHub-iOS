// App-target file. Home — the reference layout (greeting, headline, chips,
// featured carousel, list with inline play), rounded + spaced, in our palette.
import SwiftUI
import GeetHubKit

struct HomeView: View {
    @Environment(Session.self) private var session
    @Environment(PlayerEngine.self) private var player
    var onSelectTab: (Int) -> Void = { _ in }

    @State private var newest: [Album] = []
    @State private var frequent: [Album] = []
    @State private var recent: [Album] = []
    @State private var genres: [Genre] = []
    @State private var filter = 0
    @State private var isLoading = true

    private let filters = ["All", "Recently Added", "Most Played", "Mixes"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    header
                    headline
                    chips
                    featuredSection
                    listSection
                }
                .padding(.top, 12)
                .padding(.bottom, 140)
            }
            .paperBackground()
            .navigationBarHidden(true)
            .navigationDestination(for: Album.self) { AlbumDetailView(album: $0) }
            .overlay { if isLoading { ProgressView() } }
        }
        .task { await load() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Circle().fill(Theme.surface).frame(width: 46, height: 46)
                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                .overlay(Image(systemName: "opticaldisc").foregroundStyle(Theme.teal))
            VStack(alignment: .leading, spacing: 2) {
                Text(timeGreeting).retro(11, .light, color: Theme.graphite, tracking: 1.5)
                Text(session.client?.credentials.username ?? "friend").retro(15, .semibold, tracking: 1)
            }
            Spacer()
            roundButton("heart") { onSelectTab(2) }
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

    private var headline: some View {
        Text("Your records,\nanytime.")
            .retro(38, .bold, tracking: 0.5)
            .fixedSize(horizontal: false, vertical: true)
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
            HStack(spacing: 10) {
                ForEach(Array(filters.enumerated()), id: \.offset) { index, title in
                    Button { filter = index } label: { Chip(title: title, filled: filter == index) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Featured carousel

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Curated for you", trailing: "See all")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    FeaturedCard(title: "Discover", subtitle: "A fresh shuffle from your whole library",
                                 filled: true, icon: "shuffle") { Task { await shuffleAll() } }
                    FeaturedCard(title: "Rediscover", subtitle: "A random album, start to finish",
                                 filled: false, icon: "opticaldisc") { Task { await playRandomAlbum() } }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - List section (chip-driven)

    @ViewBuilder private var listSection: some View {
        if filter == 3 {
            mixes
        } else {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: listTitle, trailing: "See all")
                LazyVStack(spacing: 16) {
                    ForEach(listAlbums.prefix(8)) { album in
                        AlbumRow(album: album) { Task { await playAlbum(album) } }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var listTitle: String {
        switch filter {
        case 2: return "Most Played"
        default: return "Recently Added"
        }
    }

    private var listAlbums: [Album] {
        switch filter {
        case 2: return frequent
        case 1: return newest
        default: return newest.isEmpty ? recent : newest
        }
    }

    private var mixes: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Mixes")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(genres.prefix(14)) { genre in
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
        async let n = client.albumList(type: "newest", size: 24)
        async let f = client.albumList(type: "frequent", size: 24)
        async let r = client.albumList(type: "recent", size: 24)
        async let g = client.genres()
        newest = (try? await n) ?? []
        frequent = (try? await f) ?? []
        recent = (try? await r) ?? []
        genres = (try? await g) ?? []
        isLoading = false
    }

    private func shuffleAll() async {
        guard let c = session.client, let songs = try? await c.randomSongs(count: 100), !songs.isEmpty else { return }
        player.play(songs, startAt: 0)
    }
    private func playRandomAlbum() async {
        guard let album = newest.randomElement() ?? frequent.randomElement() else { return }
        await playAlbum(album)
    }
    private func playAlbum(_ album: Album) async {
        guard let c = session.client, let songs = try? await c.album(id: album.id)?.song, !songs.isEmpty else { return }
        player.play(songs, startAt: 0)
    }
    private func playGenre(_ name: String) async {
        guard let c = session.client, let songs = try? await c.songsByGenre(name, count: 100), !songs.isEmpty else { return }
        player.play(songs, startAt: 0)
    }
}

// MARK: - Home components

private struct AlbumRow: View {
    let album: Album
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            NavigationLink(value: album) {
                HStack(spacing: 14) {
                    ArtworkImage(coverArt: album.coverArt, size: 56, shape: .sleeve, corner: 12)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(album.name).retro(14, .semibold).lineLimit(1)
                        Text("\(album.artist ?? "Unknown") · \(album.songCount ?? 0) songs")
                            .retro(10, .light, color: Theme.graphite, tracking: 1).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button(action: onPlay) {
                Image(systemName: "play.fill").font(.system(size: 14)).foregroundStyle(.white)
                    .frame(width: 38, height: 38).background(Theme.teal, in: Circle())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct FeaturedCard: View {
    let title: String
    let subtitle: String
    let filled: Bool
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: icon).font(.title3)
                    .foregroundStyle(filled ? .white : Theme.teal)
                Spacer(minLength: 12)
                Text(title).retro(24, .bold, color: filled ? .white : Theme.ink, tracking: 0.5)
                Text(subtitle)
                    .retro(10, .regular, color: filled ? .white.opacity(0.9) : Theme.graphite, tracking: 0.8)
                    .lineLimit(2).padding(.top, 4)
                Spacer(minLength: 12)
                HStack(spacing: 10) {
                    Image(systemName: "play.fill").font(.system(size: 13))
                        .foregroundStyle(filled ? Theme.teal : .white)
                        .frame(width: 36, height: 36)
                        .background(filled ? .white : Theme.teal, in: Circle())
                    Image(systemName: "heart").foregroundStyle(filled ? .white.opacity(0.9) : Theme.graphite)
                    Spacer()
                }
            }
            .padding(20)
            .frame(width: 280, height: 190, alignment: .leading)
            .background(filled ? Theme.teal : Theme.surface,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(filled ? .clear : Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
