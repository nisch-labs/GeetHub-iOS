// App-target file. Reusable row/cell views, retro liner-note styling.
import SwiftUI
import GeetHubKit

struct SongRow: View {
    let song: Song
    var isPlaying: Bool = false
    var favorited: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ArtworkImage(coverArt: song.coverArt, size: 44, shape: .sleeve)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if isPlaying {
                        Image(systemName: "waveform").font(.caption2).foregroundStyle(Theme.teal)
                    }
                    Text(song.title).retro(15, .medium).lineLimit(1)
                }
                Text(song.artist ?? "Unknown artist")
                    .retro(11, .light, color: Theme.graphite, tracking: 1).lineLimit(1)
            }
            Spacer(minLength: 8)
            if favorited {
                Image(systemName: "heart.fill").font(.caption2).foregroundStyle(Theme.teal)
            }
            if song.isYouTube {
                Text("YouTube")
                    .retro(9, .semibold, color: Theme.teal, tracking: 1.5)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .overlay(Capsule().strokeBorder(Theme.teal.opacity(0.4), lineWidth: 1))
            } else if let d = song.duration {
                Text(Self.time(d))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.graphite)
            }
        }
        .padding(.vertical, 2)
    }

    static func time(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct AlbumCell: View {
    let album: Album

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // The sleeve: sharp square, faint hairline.
            ArtworkImage(coverArt: album.coverArt, size: 168, shape: .sleeve)
            Text(album.name).retro(13, .semibold).lineLimit(1)
            Text(album.artist ?? "").retro(10, .light, color: Theme.graphite, tracking: 1).lineLimit(1)
        }
    }
}
