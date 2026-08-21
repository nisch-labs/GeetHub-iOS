// App-target file. "Add to playlist" coordinator + sheet, presented app-wide.
import SwiftUI
import GeetHubKit

@MainActor
@Observable
final class PlaylistPicker {
    var song: Song?
    func pick(_ song: Song) { self.song = song }
}

struct AddToPlaylistSheet: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    let song: Song

    @State private var playlists: [Playlist] = []
    @State private var newName = ""
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Add to playlist").retro(22, .bold, tracking: 1)
                        Text(song.title).retro(11, .light, color: Theme.graphite, tracking: 1).lineLimit(1)
                    }
                    .padding(.horizontal, 20).padding(.top, 8)

                    // New playlist
                    HStack(spacing: 10) {
                        TextField("New playlist name", text: $newName)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(Theme.surface)
                            .overlay(Rectangle().strokeBorder(Theme.hairline, lineWidth: 1))
                        Button { Task { await createAndAdd() } } label: {
                            Image(systemName: "plus").foregroundStyle(.white)
                                .frame(width: 44, height: 44).background(Theme.teal)
                        }
                        .buttonStyle(.plain)
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty || busy)
                    }
                    .padding(.horizontal, 20)

                    // Existing playlists
                    LazyVStack(spacing: 0) {
                        ForEach(playlists) { playlist in
                            Button { Task { await add(to: playlist) } } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "music.note.list").foregroundStyle(Theme.graphite)
                                        .frame(width: 40, height: 40)
                                        .background(Theme.surface)
                                        .overlay(Rectangle().strokeBorder(Theme.hairline, lineWidth: 1))
                                    Text(playlist.name).retro(14, .medium).lineLimit(1)
                                    Spacer()
                                    Text("\(playlist.songCount ?? 0)")
                                        .font(.system(.footnote, design: .monospaced)).foregroundStyle(Theme.graphite)
                                }
                                .padding(.horizontal, 20).padding(.vertical, 10).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 72)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .paperBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.tint(Theme.teal)
                }
            }
            .overlay { if busy { ProgressView() } }
        }
        .tint(Theme.teal)
        .task { playlists = (try? await session.client?.playlists()) ?? [] }
    }

    private func add(to playlist: Playlist) async {
        busy = true
        try? await session.client?.addToPlaylist(playlistId: playlist.id, songId: song.id)
        busy = false
        dismiss()
    }

    private func createAndAdd() async {
        busy = true
        if let created = try? await session.client?.createPlaylist(name: newName) {
            try? await session.client?.addToPlaylist(playlistId: created.id, songId: song.id)
        }
        busy = false
        dismiss()
    }
}
