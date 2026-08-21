// App-target file. "See all" destinations — full album grid / song list.
import SwiftUI
import GeetHubKit

struct AlbumGridScreen: View {
    let title: String
    let albums: [Album]
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 20)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(albums) { album in
                    NavigationLink(value: album) { AlbumCell(album: album) }.buttonStyle(.plain)
                }
            }
            .padding(20).padding(.bottom, 120)
        }
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .principal) { Text(title).retro(12, .semibold, tracking: 2) } }
    }
}

struct SongsScreen: View {
    let title: String
    let songs: [Song]

    var body: some View {
        ScrollView {
            SongList(songs: songs).padding(.bottom, 120)
        }
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .principal) { Text(title).retro(12, .semibold, tracking: 2) } }
    }
}

/// A section header whose trailing "See all" pushes a destination.
struct SectionHeaderLink<Destination: View>: View {
    let title: String
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).retro(20, .bold, tracking: 1)
            Spacer()
            NavigationLink(destination: destination) {
                Text("See all").retro(10, .light, color: Theme.graphite, tracking: 1.5)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }
}
