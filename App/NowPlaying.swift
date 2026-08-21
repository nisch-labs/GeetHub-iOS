// App-target file. Mini now-playing bar + the full "record on the platter" player.
import SwiftUI
import GeetHubKit

// MARK: - Mini bar

struct NowPlayingBar: View {
    @Environment(PlayerEngine.self) private var player
    var onTap: () -> Void = {}

    var body: some View {
        if let song = player.current {
            Button(action: onTap) {
                HStack(spacing: 10) {
                    ArtworkImage(coverArt: song.coverArt, size: 38, shape: .sleeve)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title).retro(13, .medium).lineLimit(1)
                        Text(song.artist ?? "").retro(9, .light, color: Theme.graphite, tracking: 1).lineLimit(1)
                    }
                    Spacer()
                    Button { player.togglePlayPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3).foregroundStyle(Theme.teal)
                    }.buttonStyle(.plain)
                    Button { player.next() } label: {
                        Image(systemName: "forward.end").font(.body).foregroundStyle(Theme.ink)
                    }.buttonStyle(.plain).padding(.leading, 4)
                }
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Theme.surface)
                .overlay(Rectangle().fill(Theme.hairline).frame(height: 1), alignment: .top)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Full player

struct FullPlayerView: View {
    @Environment(PlayerEngine.self) private var player
    @Environment(\.dismiss) private var dismiss

    private var progress: Double {
        guard player.duration > 0 else { return 0 }
        return min(max(player.currentTime / player.duration, 0), 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer()
            record
            Spacer()
            trackInfo
            transport
        }
        .paperBackground()
    }

    // Header: back · album · more
    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.headline)
            }
            Spacer()
            Text(player.current?.album ?? "Now Playing")
                .retro(13, .medium, tracking: 3).lineLimit(1)
            Spacer()
            Image(systemName: "ellipsis").font(.headline)
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    // The record: circular art + teal tonearm arc + spindle + knob
    private var record: some View {
        let art: CGFloat = 280
        let ring: CGFloat = art + 22
        let ringRadius = ring / 2
        return ZStack {
            Circle().trim(from: 0, to: progress)
                .stroke(Theme.teal, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: ring, height: ring)

            ArtworkImage(coverArt: player.current?.coverArt, size: art, shape: .record)
                .shadow(color: .black.opacity(0.08), radius: 18, y: 10)

            // 45-rpm spindle
            Circle().fill(Theme.surface)
                .frame(width: 30, height: 30)
                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                .overlay(Circle().fill(Theme.ink.opacity(0.85)).frame(width: 5, height: 5))

            // Arc knob
            Circle().fill(Theme.teal)
                .frame(width: 16, height: 16)
                .overlay(Circle().fill(Theme.surface).frame(width: 6, height: 6))
                .offset(y: -ringRadius)
                .rotationEffect(.degrees(360 * progress))
                .opacity(progress > 0.001 ? 1 : 0)
        }
        .frame(width: ring, height: ring)
    }

    // Title + elapsed time, then artist
    private var trackInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(player.current?.title ?? "—").retro(26, .semibold, tracking: 1).lineLimit(1)
                Spacer(minLength: 12)
                Text(SongRow.time(Int(player.currentTime)))
                    .font(.system(size: 20, design: .monospaced))
                    .foregroundStyle(Theme.ink)
            }
            Text(player.current?.artist ?? "")
                .retro(13, .regular, color: Theme.graphite, tracking: 2).lineLimit(1)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 20)
    }

    // Hairline-divided transport cells
    private var transport: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
            HStack(spacing: 0) {
                transportButton("backward.end", tint: Theme.ink) { player.previous() }
                divider
                transportButton(player.isPlaying ? "pause" : "play", tint: Theme.teal) { player.togglePlayPause() }
                divider
                transportButton("forward.end", tint: Theme.ink) { player.next() }
            }
            .frame(height: 116)
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.hairline).frame(width: 1)
    }

    private func transportButton(_ symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
