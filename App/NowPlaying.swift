// App-target file. Mini now-playing bar + the full "record on the platter" player.
import SwiftUI
import GeetHubKit

// MARK: - Now-playing bottom accessory (adapts to the tab bar's minimize state)

struct NowPlayingAccessory: View {
    @Environment(PlayerEngine.self) private var player
    #if !targetEnvironment(macCatalyst)
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    private var isInline: Bool { placement == .inline }
    #else
    // Catalyst doesn't have the iOS-26 tab-bar accessory placement env; the
    // mini player is rendered via .safeAreaInset instead, always expanded.
    private var isInline: Bool { false }
    #endif
    var onTap: () -> Void = {}
    /// If provided, a small "sidebar.right" button appears at the trailing edge.
    /// Used on iPad + Mac Catalyst to dock the full player to the right pane.
    var onDock: (() -> Void)? = nil

    var body: some View {
        Button {
            if player.current != nil { onTap() }
        } label: {
            HStack(spacing: 10) {
                artwork
                VStack(alignment: .leading, spacing: 1) {
                    Text(player.current?.title ?? "Not Playing").retro(12, .medium).lineLimit(1)
                    if !isInline, let artist = player.current?.artist, !artist.isEmpty {
                        Text(artist).retro(8, .light, color: Theme.graphite, tracking: 1).lineLimit(1)
                    }
                }
                Spacer(minLength: 6)
                if player.current != nil {
                    HStack(spacing: 18) {
                        if !isInline {
                            Button { player.previous() } label: {
                                Image(systemName: "backward.fill").foregroundStyle(Theme.ink)
                            }.buttonStyle(.plain)
                        }
                        Button { player.togglePlayPause() } label: {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .foregroundStyle(Theme.accent)
                        }.buttonStyle(.plain)
                        if !isInline {
                            Button { player.next() } label: {
                                Image(systemName: "forward.fill").foregroundStyle(Theme.ink)
                            }.buttonStyle(.plain)
                        }
                    }
                    .font(.body)
                } else {
                    Image(systemName: "play.fill").font(.body).foregroundStyle(Theme.graphite)
                }
                if let onDock {
                    Button { onDock() } label: {
                        Image(systemName: "sidebar.right").foregroundStyle(Theme.graphite)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 6)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var artwork: some View {
        if let art = player.current?.coverArt {
            ArtworkImage(coverArt: art, size: 30, shape: .sleeve, corner: 6)
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.hairline)
                .frame(width: 30, height: 30)
                .overlay(Image(systemName: "music.note").font(.caption).foregroundStyle(Theme.graphite))
        }
    }
}

// MARK: - Full player

struct FullPlayerView: View {
    @Environment(PlayerEngine.self) private var player
    @Environment(PlaylistPicker.self) private var picker
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showLyrics = false
    @State private var showQueue = false
    @State private var showDevices = false
    /// When non-nil, the header's leading button becomes an undock (xmark)
    /// action instead of the modal-dismiss chevron. Used by the docked pane
    /// on iPad + Mac Catalyst.
    var onClose: (() -> Void)? = nil

    private var progress: Double {
        guard player.duration > 0 else { return 0 }
        return min(max(player.currentTime / player.duration, 0), 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 8)
            record
            Spacer(minLength: 8)
            trackInfo
            scrubber
            secondaryControls
            volumeRow
            transport
        }
        .paperBackground()
        .sheet(isPresented: $showLyrics) { LyricsView().environment(player) }
        .sheet(isPresented: $showQueue) { QueueView().environment(player) }
        .sheet(isPresented: $showDevices) { DevicesSheet().environment(player) }
    }

    // Header: back · (spacer) · favorite/download · menu
    private var header: some View {
        HStack(spacing: 16) {
            Button {
                if let onClose { onClose() } else { dismiss() }
            } label: {
                Image(systemName: onClose != nil ? "xmark" : "chevron.down").font(.headline)
            }
            Spacer()
            Button { showDevices = true } label: {
                Image(systemName: player.devices.count > 1
                      ? "hifispeaker.and.appletv" : "hifispeaker")
                    .font(.headline).foregroundStyle(Theme.ink)
            }
            if player.current?.isVirtual == true {
                if let pct = player.currentDownloadPercent {
                    ProgressRing(percent: pct).frame(width: 20, height: 20)
                } else {
                    Button { player.saveCurrentToLibrary() } label: {
                        Image(systemName: player.isCurrentSaved ? "checkmark.circle.fill" : "arrow.down.circle")
                            .font(.headline)
                            .foregroundStyle(player.isCurrentSaved ? Theme.accent : Theme.ink)
                    }
                }
            } else {
                Button { player.toggleFavorite() } label: {
                    Image(systemName: player.isCurrentFavorite ? "heart.fill" : "heart")
                        .font(.headline)
                        .foregroundStyle(player.isCurrentFavorite ? Theme.accent : Theme.ink)
                }
            }
            Menu {
                if let song = player.current {
                    Button { picker.pick(song) } label: { Label("Add to playlist…", systemImage: "plus") }
                }
                Menu {
                    Button("Off") { player.setSleep(minutes: nil) }
                    Button("15 minutes") { player.setSleep(minutes: 15) }
                    Button("30 minutes") { player.setSleep(minutes: 30) }
                    Button("1 hour") { player.setSleep(minutes: 60) }
                } label: { Label(player.isSleepArmed ? "Sleep timer · on" : "Sleep timer", systemImage: "moon.zzz") }
            } label: {
                Image(systemName: "ellipsis").font(.headline)
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    // The record: a pressed vinyl — art as label, grooves + rim, spins while
    // playing — wrapped by the teal tonearm arc (which does NOT spin: it's time).
    private var record: some View {
        let art: CGFloat = 264
        let ring: CGFloat = art + 22
        return ZStack {
            // Progress arc (represents elapsed time)
            Circle().trim(from: 0, to: progress)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: ring, height: ring)

            // The spinning disc
            TimelineView(.animation(paused: !player.isPlaying || reduceMotion)) { timeline in
                vinyl(art: art).rotationEffect(.degrees(spinAngle(timeline.date)))
            }
        }
        .frame(width: ring, height: ring)
    }

    private func spinAngle(_ date: Date) -> Double {
        guard player.isPlaying, !reduceMotion else { return 0 }
        let revolution = 14.0   // seconds per turn
        return (date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: revolution) / revolution) * 360
    }

    private func vinyl(art: CGFloat) -> some View {
        let r = art / 2
        return ZStack {
            // Black rim just outside the art
            Circle().fill(Color.black).frame(width: art + 10, height: art + 10)

            ArtworkImage(coverArt: player.current?.coverArt, size: art, shape: .record)
                .shadow(color: .black.opacity(0.12), radius: 20, y: 12)

            // Grooves — faint concentric rings over the outer band
            ForEach(0..<9, id: \.self) { i in
                let rr = r * (0.60 + 0.043 * Double(i))
                Circle().stroke(Color.black.opacity(0.07), lineWidth: 1)
                    .frame(width: rr * 2, height: rr * 2)
            }
            Circle().strokeBorder(Color.black.opacity(0.35), lineWidth: 1).frame(width: art, height: art)

            // Label ring + 45-rpm spindle
            Circle().stroke(Color.white.opacity(0.5), lineWidth: 1).frame(width: 96, height: 96)
            Circle().fill(Theme.surface)
                .frame(width: 30, height: 30)
                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                .overlay(Circle().fill(Theme.ink.opacity(0.85)).frame(width: 6, height: 6))
        }
    }

    // YouTube tag, then title (marquee), then artist
    private var trackInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let s = player.current, let src = s.virtualSource, !player.savedYouTube.contains(s.id) {
                SourceTag(source: src)
            }
            MarqueeText(text: player.current?.title ?? "—", size: 24, weight: .semibold, tracking: 1)
                .id(player.current?.id)
            Text(player.current?.artist ?? "")
                .retro(12, .regular, color: Theme.graphite, tracking: 2).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.bottom, 14)
    }

    // Draggable scrubber + elapsed / remaining
    private var scrubber: some View {
        VStack(spacing: 6) {
            Scrubber(current: player.currentTime, duration: player.duration) { player.seek(to: $0) }
            HStack {
                Text(SongRow.time(Int(player.currentTime)))
                Spacer()
                Text("-" + SongRow.time(Int(max(player.duration - player.currentTime, 0))))
            }
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(Theme.graphite)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 16)
    }

    // Shuffle · lyrics · queue · repeat
    private var secondaryControls: some View {
        HStack {
            iconButton("shuffle", active: player.isShuffled) { player.toggleShuffle() }
            Spacer()
            iconButton("text.quote", active: false) { showLyrics = true }
            Spacer()
            iconButton("list.bullet", active: false) { showQueue = true }
            Spacer()
            iconButton(repeatSymbol, active: player.repeatMode != .off) { player.cycleRepeat() }
        }
        .padding(.horizontal, 36)
        .padding(.bottom, 14)
    }

    private func iconButton(_ symbol: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17))
                .foregroundStyle(active ? Theme.accent : Theme.graphite)
                .frame(width: 44, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var repeatSymbol: String {
        player.repeatMode == .one ? "repeat.1" : "repeat"
    }

    // App-only volume slider — hardware buttons still control the system level.
    private var volumeRow: some View {
        let bind = Binding<Double>(
            get: { Double(player.volume) },
            set: { player.setVolume(Float($0)) },
        )
        return HStack(spacing: 12) {
            Button { player.setVolume(0) } label: {
                Image(systemName: player.volume == 0 ? "speaker.slash.fill" : "speaker.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.graphite)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Slider(value: bind, in: 0...1)
                .tint(Theme.accent)
            Button { player.setVolume(1) } label: {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.graphite)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 14)
    }

    // Hairline-divided transport — whole cell is the button (cassette feel)
    private var transport: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
            HStack(spacing: 0) {
                transportButton("backward.end", tint: Theme.ink) { player.previous() }
                divider
                transportButton(player.isPlaying ? "pause" : "play", tint: Theme.accent) { player.togglePlayPause() }
                divider
                transportButton("forward.end", tint: Theme.ink) { player.next() }
            }
            .frame(height: 108)
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.hairline).frame(width: 1)
    }

    private func transportButton(_ symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(tint)
        }
        .buttonStyle(CassetteButtonStyle())
    }
}

/// The whole cell is tappable and depresses like a physical transport key.
struct CassetteButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(configuration.isPressed ? Theme.accent.opacity(0.12) : Color.clear)
            .contentShape(Rectangle())
    }
}

/// Minimal draggable seek bar.
struct Scrubber: View {
    let current: Double
    let duration: Double
    let onSeek: (Double) -> Void
    @State private var dragValue: Double? = nil

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let value = dragValue ?? current
            let fraction = duration > 0 ? min(max(value / duration, 0), 1) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.hairline).frame(height: 3)
                Capsule().fill(Theme.accent).frame(width: width * fraction, height: 3)
                Circle().fill(Theme.accent).frame(width: 14, height: 14)
                    .offset(x: width * fraction - 7)
            }
            .frame(height: 20)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let x = min(max(0, v.location.x), width)
                        dragValue = duration * Double(x / width)
                    }
                    .onEnded { v in
                        let x = min(max(0, v.location.x), width)
                        onSeek(duration * Double(x / width))
                        dragValue = nil
                    }
            )
        }
        .frame(height: 20)
    }
}
