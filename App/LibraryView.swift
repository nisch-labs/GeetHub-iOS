// App-target file. Library — Songs / Albums / Artists / Playlists.
import SwiftUI
import GeetHubKit

struct LibraryView: View {
    @Environment(Session.self) private var session
    @State private var tab = 1   // default: Albums

    @State private var songs: [Song] = []
    @State private var albums: [Album] = []
    @State private var artists: [Artist] = []
    @State private var playlists: [Playlist] = []
    @State private var loadedSongs = false

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 20)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Library").retro(30, .bold, tracking: 1)
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.top, 8)

                SegmentedBar(options: ["Songs", "Albums", "Artists", "Playlists"], selection: $tab)

                ScrollView {
                    Group {
                        switch tab {
                        case 0: SongList(songs: songs)
                        case 1: albumGrid
                        case 2: artistList
                        default: playlistList
                        }
                    }
                    .padding(.bottom, 120)
                }
                .refreshable {
                    loadedSongs = false
                    await loadTop()
                    if tab == 0 { await loadSongs() }
                }
            }
            .paperBackground()
            .navigationBarHidden(true)
            .navigationDestination(for: Album.self) { AlbumDetailView(album: $0) }
            .navigationDestination(for: Artist.self) { ArtistDetailView(artist: $0) }
            .navigationDestination(for: Playlist.self) { PlaylistDetailView(playlist: $0) }
        }
        .task { await loadTop() }
        .onChange(of: tab) { _, t in if t == 0 { Task { await loadSongs() } } }
    }

    private var albumGrid: some View {
        LazyVGrid(columns: columns, spacing: 24) {
            ForEach(albums) { album in AlbumCell(album: album).asLink(album) }
        }
        .padding(.horizontal, 20).padding(.top, 8)
    }

    private var artistList: some View {
        LazyVStack(spacing: 0) {
            ForEach(artists) { artist in
                NavigationLink(value: artist) {
                    HStack(spacing: 14) {
                        Circle().fill(Theme.surface).frame(width: 44, height: 44)
                            .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                            .overlay(Image(systemName: "music.mic").foregroundStyle(Theme.graphite))
                        Text(artist.name).retro(15, .medium).lineLimit(1)
                        Spacer()
                        if let n = artist.albumCount {
                            Text("\(n)").font(.system(.footnote, design: .monospaced)).foregroundStyle(Theme.graphite)
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 11).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 78)
            }
        }
        .padding(.top, 4)
    }

    private var playlistList: some View {
        LazyVStack(spacing: 0) {
            ForEach(playlists) { playlist in
                NavigationLink(value: playlist) {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 0).fill(Theme.surface).frame(width: 44, height: 44)
                            .overlay(Rectangle().strokeBorder(Theme.hairline, lineWidth: 1))
                            .overlay(Image(systemName: "music.note.list").foregroundStyle(Theme.graphite))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(playlist.name).retro(15, .medium).lineLimit(1)
                            if let n = playlist.songCount {
                                Text("\(n) songs").retro(9, .light, color: Theme.graphite, tracking: 1)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20).padding(.vertical, 11).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 78)
            }
        }
        .padding(.top, 4)
    }

    private func loadTop() async {
        guard let client = session.client else { return }
        async let a = client.albumList(type: "alphabeticalByName", size: 200)
        async let ar = client.artists()
        async let pl = client.playlists()
        albums = (try? await a) ?? []
        artists = (try? await ar) ?? []
        playlists = (try? await pl) ?? []
    }

    private func loadSongs() async {
        guard !loadedSongs, let client = session.client else { return }
        songs = (try? await client.allSongs(size: 500)) ?? []
        loadedSongs = true
    }
}

private extension View {
    func asLink(_ album: Album) -> some View {
        NavigationLink(value: album) { self }.buttonStyle(.plain)
    }
}
