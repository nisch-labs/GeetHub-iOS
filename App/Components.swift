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

/// Pill chip (genres, mixes).
struct Chip: View {
    let title: String
    var filled: Bool = false

    var body: some View {
        Text(title).retro(12, .medium, color: filled ? .white : Theme.ink, tracking: 1.5)
            .padding(.horizontal, 16).padding(.vertical, 9)
            .background(filled ? Theme.teal : Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: filled ? 0 : 1))
    }
}

/// A plain tappable list of songs that plays on tap.
struct SongList: View {
    let songs: [Song]
    @Environment(PlayerEngine.self) private var player

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                Button { player.play(songs, startAt: index) } label: {
                    SongRow(song: song, isPlaying: player.current?.id == song.id)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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
                            .fill(selection == index ? Theme.teal : .clear)
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
