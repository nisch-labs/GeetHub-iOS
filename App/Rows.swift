// App-target file. Reusable row/cell views.
import SwiftUI
import GeetHubKit

struct SongRow: View {
    let song: Song
    var isPlaying: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ArtworkImage(coverArt: song.coverArt, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if isPlaying {
                        Image(systemName: "speaker.wave.2.fill").font(.caption2).foregroundStyle(.tint)
                    }
                    Text(song.title).foregroundStyle(Color.primary).lineLimit(1)
                }
                Text(song.artist ?? "Unknown artist")
                    .font(.subheadline).foregroundStyle(Color.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            if song.isYouTube {
                Text("YouTube")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.red.opacity(0.15), in: Capsule())
                    .foregroundStyle(.red)
            } else if let d = song.duration {
                Text(Self.time(d)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        }
    }

    static func time(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct AlbumCell: View {
    let album: Album

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ArtworkImage(coverArt: album.coverArt, size: 160)
            Text(album.name).font(.subheadline.weight(.medium))
                .foregroundStyle(Color.primary).lineLimit(1)
            Text(album.artist ?? "").font(.caption)
                .foregroundStyle(Color.secondary).lineLimit(1)
        }
    }
}
