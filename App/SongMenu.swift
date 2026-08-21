// App-target file. Per-song actions — a trailing "•••" menu and a matching
// long-press context menu, sharing the same actions.
import SwiftUI
import GeetHubKit

private struct SongActions: View {
    @Environment(PlayerEngine.self) private var player
    @Environment(PlaylistPicker.self) private var picker
    let song: Song

    var body: some View {
        Button { player.enqueueNext(song) } label: { Label("Play next", systemImage: "text.line.first.and.arrowtriangle.forward") }
        Button { player.enqueueLast(song) } label: { Label("Add to queue", systemImage: "text.append") }
        Button { player.setFavorite(song) } label: {
            Label(player.isFavorite(song) ? "Remove favorite" : "Favorite",
                  systemImage: player.isFavorite(song) ? "heart.slash" : "heart")
        }
        Button { picker.pick(song) } label: { Label("Add to playlist…", systemImage: "plus") }
    }
}

/// The trailing "•••" menu button for a song row.
struct SongMenuButton: View {
    let song: Song
    var body: some View {
        Menu { SongActions(song: song) } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15))
                .foregroundStyle(Theme.graphite)
                .frame(width: 36, height: 44)
                .contentShape(Rectangle())
        }
    }
}

extension View {
    /// Long-press context menu with the same song actions.
    func songContextMenu(_ song: Song) -> some View {
        contextMenu { SongActions(song: song) }
    }
}
