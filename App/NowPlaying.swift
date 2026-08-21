// App-target file. Mini now-playing bar + full-screen player.
import SwiftUI
import GeetHubKit

struct NowPlayingBar: View {
    @Environment(PlayerEngine.self) private var player
    @State private var showFull = false

    var body: some View {
        if let song = player.current {
            Button { showFull = true } label: {
                HStack(spacing: 10) {
                    ArtworkImage(coverArt: song.coverArt, size: 40)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(song.title).font(.subheadline.weight(.medium)).lineLimit(1)
                        Text(song.artist ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Button { player.togglePlayPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").font(.title3)
                    }.buttonStyle(.plain)
                    Button { player.next() } label: {
                        Image(systemName: "forward.fill").font(.body)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .foregroundStyle(.primary)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 8)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showFull) { FullPlayerView() }
        }
    }
}

struct FullPlayerView: View {
    @Environment(PlayerEngine.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 28) {
            Capsule().fill(.secondary).frame(width: 40, height: 5).padding(.top, 8)
            Spacer()
            ArtworkImage(coverArt: player.current?.coverArt, size: 300)
                .shadow(radius: 20, y: 10)
            VStack(spacing: 4) {
                Text(player.current?.title ?? "").font(.title2.bold()).lineLimit(1)
                Text(player.current?.artist ?? "").foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                Slider(value: Binding(
                    get: { player.currentTime },
                    set: { player.seek(to: $0) }
                ), in: 0...(max(player.duration, 1)))
                HStack {
                    Text(SongRow.time(Int(player.currentTime))).monospacedDigit()
                    Spacer()
                    Text(SongRow.time(Int(player.duration))).monospacedDigit()
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            HStack(spacing: 44) {
                Button { player.previous() } label: { Image(systemName: "backward.fill").font(.title) }
                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                }
                Button { player.next() } label: { Image(systemName: "forward.fill").font(.title) }
            }
            .foregroundStyle(.primary)
            Spacer()
        }
        .padding()
        .presentationDragIndicator(.hidden)
    }
}
