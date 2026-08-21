// App-target file. Artist detail — their albums.
import SwiftUI
import GeetHubKit

struct ArtistDetailView: View {
    @Environment(Session.self) private var session
    let artist: Artist

    @State private var albums: [Album] = []
    @State private var isLoading = true

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 20)]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Circle().fill(Theme.surface).frame(width: 120, height: 120)
                    .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                    .overlay(Image(systemName: "music.mic").font(.system(size: 40)).foregroundStyle(Theme.graphite))
                    .padding(.top, 8)
                Text(artist.name).retro(22, .semibold, tracking: 1).multilineTextAlignment(.center)

                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(albums) { album in
                        NavigationLink(value: album) { AlbumCell(album: album) }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
            }
        }
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .principal) { Text(artist.name).retro(12, .medium, tracking: 2).lineLimit(1) } }
        .overlay { if isLoading { ProgressView() } }
        .task {
            albums = (try? await session.client?.artist(id: artist.id))?.album ?? []
            isLoading = false
        }
    }
}
