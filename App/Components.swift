// App-target file. Small reusable retro building blocks.
import SwiftUI
import GeetHubKit

/// Section title with an optional trailing affordance.
struct SectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).retro(20, .bold, tracking: 1)
            Spacer()
            if let trailing {
                Text(trailing).retro(10, .light, color: Theme.graphite, tracking: 1.5)
            }
        }
        .padding(.horizontal, 20)
    }
}

/// A tappable album sleeve card for horizontal shelves.
struct AlbumCard: View {
    let album: Album
    var width: CGFloat = 150

    var body: some View {
        NavigationLink(value: album) {
            VStack(alignment: .leading, spacing: 7) {
                ArtworkImage(coverArt: album.coverArt, size: width, shape: .sleeve)
                Text(album.name).retro(12, .semibold).lineLimit(1).frame(width: width, alignment: .leading)
                Text(album.artist ?? "").retro(9, .light, color: Theme.graphite, tracking: 1)
                    .lineLimit(1).frame(width: width, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Horizontal shelf of albums under a section header.
struct AlbumShelf: View {
    let title: String
    let albums: [Album]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: title, trailing: albums.isEmpty ? nil : "\(albums.count)")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(albums) { AlbumCard(album: $0) }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

/// Red source tag used on song rows and the player — "YT" for YouTube search
/// results, "YT Music" for ytmusicapi results.
struct SourceTag: View {
    let source: VirtualSource
    var body: some View {
        Text(source.shortLabel).retro(9, .semibold, color: .white, tracking: 1)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color(red: 0.90, green: 0.13, blue: 0.13),
                        in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

/// Thin accent-tinted progress ring for inline download progress.
/// Renders indeterminate (spinning arc) when ``percent`` is 0, so the user
/// always sees motion — even before the first status update lands.
struct ProgressRing: View {
    let percent: Int
    @State private var spin = false
    var body: some View {
        let p = max(0, min(100, percent))
        ZStack {
            Circle().stroke(Theme.hairline, lineWidth: 2)
            if p == 0 {
                Circle().trim(from: 0, to: 0.25)
                    .stroke(Theme.accent, style: .init(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: spin)
                    .onAppear { spin = true }
            } else {
                Circle().trim(from: 0, to: CGFloat(p) / 100)
                    .stroke(Theme.accent, style: .init(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.4), value: p)
            }
        }
    }
}

/// Pill chip (genres, mixes).
struct Chip: View {
    let title: String
    var filled: Bool = false

    var body: some View {
        Text(title).retro(12, .medium, color: filled ? .white : Theme.ink, tracking: 1.5)
            .padding(.horizontal, 16).padding(.vertical, 9)
            .background(filled ? Theme.accent : Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: filled ? 0 : 1))
    }
}

/// A plain tappable list of songs — tap to play, "•••" for actions, long-press
/// for the same menu.
struct SongList: View {
    let songs: [Song]
    @Environment(PlayerEngine.self) private var player

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                HStack(spacing: 0) {
                    Button { player.play(songs, startAt: index) } label: {
                        SongRow(song: song, isPlaying: player.current?.id == song.id,
                                favorited: player.isFavorite(song))
                            .padding(.leading, 20).padding(.vertical, 10)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .songContextMenu(song)
                    SongMenuButton(song: song).padding(.trailing, 12)
                }
                Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 76)
            }
        }
    }
}

/// Retro segmented control (Songs / Albums / Artists / Playlists).
struct SegmentedBar: View {
    let options: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 22) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, title in
                Button { selection = index } label: {
                    VStack(spacing: 6) {
                        Text(title).retro(13, selection == index ? .semibold : .regular,
                                          color: selection == index ? Theme.ink : Theme.graphite, tracking: 1.5)
                        Rectangle()
                            .fill(selection == index ? Theme.accent : .clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}
