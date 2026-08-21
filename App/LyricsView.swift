// App-target file. Lyrics for the current track (synced highlight if available).
import SwiftUI
import GeetHubKit

struct LyricsView: View {
    @Environment(Session.self) private var session
    @Environment(PlayerEngine.self) private var player
    @Environment(\.dismiss) private var dismiss

    @State private var lines: [LyricLine] = []
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Group {
                if !loaded {
                    ProgressView()
                } else if lines.isEmpty {
                    ContentUnavailableView("No lyrics",
                        systemImage: "text.quote",
                        description: Text("This track has no lyrics on the server."))
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                                Text(line.value.isEmpty ? " " : line.value)
                                    .font(.oswald(20, isActive(index) ? .semibold : .regular))
                                    .foregroundStyle(isActive(index) ? Theme.ink : Theme.graphite)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(24)
                    }
                }
            }
            .paperBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { Text("Lyrics").retro(13, .semibold, tracking: 2) }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.tint(Theme.accent) }
            }
        }
        .tint(Theme.accent)
        .task(id: player.current?.id) { await load() }
    }

    private var synced: Bool { lines.contains { $0.start != nil } }

    private var activeLineIndex: Int? {
        guard synced else { return nil }
        let nowMs = Int(player.currentTime * 1000)
        var active: Int?
        for (i, line) in lines.enumerated() {
            if let s = line.start, s <= nowMs { active = i }
        }
        return active
    }
    private func isActive(_ index: Int) -> Bool { activeLineIndex == index }

    private func load() async {
        loaded = false
        if let client = session.client, let id = player.current?.id {
            lines = (try? await client.lyrics(id: id)) ?? []
        } else {
            lines = []
        }
        loaded = true
    }
}
