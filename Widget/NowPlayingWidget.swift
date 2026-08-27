@preconcurrency import WidgetKit
import SwiftUI
import GeetHubKit

// MARK: - Timeline entry

struct NowPlayingEntry: TimelineEntry {
    let date: Date
    let snapshot: NowPlayingSnapshot?
    let favourites: FavouritesSnapshot?
    /// Preloaded artwork bytes (JPEG) for the now-playing track OR the first
    /// few favourites. Key is the coverArtURL string. Fetched by the provider
    /// so the view can decode UIImage synchronously (async in .task doesn't
    /// finish before WidgetKit snapshots the view).
    let artwork: [String: Data]
}

// MARK: - Timeline provider

/// Async provider — preloads cover-art bytes in `getTimeline` so the view
/// doesn't need to fetch during snapshot rendering.
struct NowPlayingProvider: TimelineProvider {
    func placeholder(in context: Context) -> NowPlayingEntry {
        NowPlayingEntry(date: Date(), snapshot: nil, favourites: nil, artwork: [:])
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (NowPlayingEntry) -> Void) {
        Task {
            let entry = await self.build()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<NowPlayingEntry>) -> Void) {
        Task {
            let entry = await self.build()
            let next = (entry.snapshot == nil ? 5 * 60 : 15) as TimeInterval
            completion(Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(next))))
        }
    }

    /// Read shared state, then fetch the artwork URLs it references.
    private func build() async -> NowPlayingEntry {
        let now = NowPlayingStore.read()
        let favs = FavouritesStore.read()
        var urls: [String] = []
        if let u = now?.coverArtURL { urls.append(u) }
        if now == nil, let favs { urls.append(contentsOf: favs.songs.prefix(4).compactMap(\.coverArtURL)) }
        let artwork = await fetchAll(urls: urls)
        return NowPlayingEntry(date: Date(), snapshot: now, favourites: favs, artwork: artwork)
    }

    private func fetchAll(urls: [String]) async -> [String: Data] {
        await withTaskGroup(of: (String, Data?).self) { group in
            for s in urls {
                group.addTask { (s, await Self.fetch(s)) }
            }
            var out: [String: Data] = [:]
            for await (k, v) in group { if let v { out[k] = v } }
            return out
        }
    }

    private static func fetch(_ urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 10
        return try? await URLSession.shared.data(for: req).0
    }
}

// MARK: - Widget

struct NowPlayingWidget: Widget {
    let kind = "NowPlayingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NowPlayingProvider()) { entry in
            NowPlayingWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Now Playing")
        .description("What's playing in Geet-Hub — or your favourites when idle.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - View

struct NowPlayingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NowPlayingEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            playingBody(snapshot)
        } else if let favs = entry.favourites, !favs.songs.isEmpty {
            favouritesBody(favs)
        } else {
            idleBody
        }
    }

    // MARK: Playing

    @ViewBuilder private func playingBody(_ snapshot: NowPlayingSnapshot) -> some View {
        switch family {
        case .systemMedium: mediumPlaying(snapshot)
        default:            smallPlaying(snapshot)
        }
    }

    private func smallPlaying(_ s: NowPlayingSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            artwork(url: s.coverArtURL, size: 60)
            Text(s.title).font(.system(size: 12, weight: .semibold)).lineLimit(2)
            if let a = s.artist, !a.isEmpty {
                Text(a).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func mediumPlaying(_ s: NowPlayingSnapshot) -> some View {
        HStack(spacing: 12) {
            artwork(url: s.coverArtURL, size: 72)
            VStack(alignment: .leading, spacing: 3) {
                Text(s.title).font(.system(size: 13, weight: .semibold)).lineLimit(2)
                if let a = s.artist, !a.isEmpty {
                    Text(a).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 6)
                HStack(spacing: 24) {
                    if #available(iOS 17.0, *) {
                        Button(intent: PreviousTrackIntent()) {
                            Image(systemName: "backward.fill")
                        }
                        .buttonStyle(.plain)
                        Button(intent: TogglePlayPauseIntent()) {
                            Image(systemName: s.isPlaying ? "pause.fill" : "play.fill")
                                .foregroundStyle(.tint)
                        }
                        .buttonStyle(.plain)
                        Button(intent: NextTrackIntent()) {
                            Image(systemName: "forward.fill")
                        }
                        .buttonStyle(.plain)
                    } else {
                        Image(systemName: "backward.fill")
                        Image(systemName: s.isPlaying ? "pause.fill" : "play.fill").foregroundStyle(.tint)
                        Image(systemName: "forward.fill")
                    }
                }
                .font(.system(size: 15))
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Favourites (idle state)

    @ViewBuilder private func favouritesBody(_ favs: FavouritesSnapshot) -> some View {
        switch family {
        case .systemMedium: mediumFavourites(favs)
        default:            smallFavourites(favs)
        }
    }

    private func smallFavourites(_ favs: FavouritesSnapshot) -> some View {
        // 2x2 grid of tiny cover-art tiles.
        let items = Array(favs.songs.prefix(4))
        return VStack(alignment: .leading, spacing: 6) {
            Text("Favourites").font(.caption2).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)], spacing: 4) {
                ForEach(items, id: \.songId) { s in
                    artwork(url: s.coverArtURL, size: 44)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func mediumFavourites(_ favs: FavouritesSnapshot) -> some View {
        let items = Array(favs.songs.prefix(4))
        return VStack(alignment: .leading, spacing: 8) {
            Text("Favourites").font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(items, id: \.songId) { s in
                    VStack(alignment: .leading, spacing: 4) {
                        artwork(url: s.coverArtURL, size: 60)
                        Text(s.title).font(.system(size: 10, weight: .medium)).lineLimit(1)
                        if let a = s.artist, !a.isEmpty {
                            Text(a).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Idle — shown when there's no now-playing snapshot AND we haven't
    // yet mirrored any favourites into the App Group. Opening the app once
    // triggers PlayerEngine.refreshFavouritesSnapshot() so subsequent widget
    // refreshes will land in favouritesBody instead.

    private var idleBody: some View {
        VStack(spacing: 8) {
            Image(systemName: "opticaldisc")
                .font(.system(size: 32))
                .foregroundStyle(.tint)
            Text("Not Playing").font(.system(size: 12, weight: .semibold)).foregroundStyle(.primary)
            Text("Open Geet-Hub to start")
                .font(.system(size: 10)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Artwork

    @ViewBuilder private func artwork(url: String?, size: CGFloat) -> some View {
        if let url, let data = entry.artwork[url], let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable().scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.tertiary)
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.4))
                        .foregroundStyle(.secondary)
                )
        }
    }
}
