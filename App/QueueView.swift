// App-target file. Up Next — the current track + upcoming queue.
import SwiftUI
import GeetHubKit

struct QueueView: View {
    @Environment(PlayerEngine.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let current = player.current {
                        header("Now Playing")
                        SongRow(song: current, isPlaying: true, favorited: player.isFavorite(current))
                            .padding(.horizontal, 20).padding(.vertical, 10)
                        Rectangle().fill(Theme.hairline).frame(height: 1)
                    }

                    header("Up Next")
                    let upNext = player.upNext
                    if upNext.isEmpty {
                        Text("Nothing queued")
                            .retro(11, .light, color: Theme.graphite, tracking: 1)
                            .padding(.horizontal, 20).padding(.vertical, 16)
                    } else {
                        ForEach(Array(upNext.enumerated()), id: \.offset) { index, song in
                            HStack(spacing: 0) {
                                Button { player.playUpNext(index) } label: {
                                    SongRow(song: song, favorited: player.isFavorite(song))
                                        .padding(.leading, 20).padding(.vertical, 10)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Button { player.removeUpNext(index) } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(Theme.graphite)
                                        .frame(width: 40, height: 44).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain).padding(.trailing, 10)
                            }
                            Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 76)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .paperBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { Text("Queue").retro(13, .semibold, tracking: 2) }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.tint(Theme.accent) }
            }
        }
        .tint(Theme.accent)
    }

    private func header(_ title: String) -> some View {
        Text(title).retro(12, .bold, color: Theme.graphite, tracking: 2)
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 6)
    }
}
