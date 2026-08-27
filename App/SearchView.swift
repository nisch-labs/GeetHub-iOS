// App-target file. Search — custom title + field, recent searches, live results
// from the library and YouTube, with play / Save-to-Library.
import SwiftUI
import GeetHubKit

struct SearchView: View {
    @Environment(Session.self) private var session
    @Environment(PlayerEngine.self) private var player
    @Environment(DownloadsCoordinator.self) private var downloads

    @State private var query = ""
    @State private var songs: [Song] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var toast: String?
    @State private var recents: [String] = []
    @State private var folders: [String] = []
    @State private var showAntra = false
    @AppStorage("ytSearchSource") private var ytSource: String = "ytmusic"

    private let recentsKey = "recentSearches"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                downloadsBanner
                searchField
                sourcePicker
                content
            }
            .paperBackground()
            .navigationBarHidden(true)
            .overlay(alignment: .bottom) { toastView }
            .sheet(isPresented: $showAntra) {
                AntraView().environment(session)
            }
        }
        .tint(Theme.accent)
        .onChange(of: query) { _, q in scheduleSearch(q) }
        .onChange(of: ytSource) { _, _ in scheduleSearch(query) }
        .task {
            loadRecents()
            if folders.isEmpty, let client = session.client {
                folders = (try? await client.libraryFolders()) ?? []
            }
        }
    }

    // Two chips: [YouTube] [YT Music] — persisted default via @AppStorage,
    // shared with the "Search" card in Settings. Switching re-runs the query.
    private var sourcePicker: some View {
        HStack(spacing: 8) {
            sourceChip("YouTube", value: "youtube")
            sourceChip("YT Music", value: "ytmusic")
            Spacer()
        }
        .padding(.horizontal, 20).padding(.bottom, 10)
    }

    private func sourceChip(_ title: String, value: String) -> some View {
        Button { ytSource = value } label: {
            Chip(title: title, filled: ytSource == value)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header + field

    // Compact strip above the search field — visible when any Antra job is
    // in-flight. Tapping opens the full Antra dashboard.
    @ViewBuilder private var downloadsBanner: some View {
        if let job = downloads.activeJobs.first {
            Button { showAntra = true } label: {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small).tint(Theme.accent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(job.title ?? "Downloading…")
                            .retro(11, .semibold, tracking: 1)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            if let pct = job.progress {
                                Text("\(pct)%").font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(Theme.accent)
                            }
                            if downloads.activeJobs.count > 1 {
                                Text("· +\(downloads.activeJobs.count - 1) more")
                                    .retro(8, .light, color: Theme.graphite, tracking: 1)
                            }
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.graphite)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Theme.accent.opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.accent.opacity(0.25), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20).padding(.bottom, 10)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Search").retro(20, .bold, tracking: 1)
            Spacer()
            Button { showAntra = true } label: {
                Image(systemName: "shippingbox")
                    .font(.title3).foregroundStyle(Theme.ink)
                    .frame(width: 36, height: 36)
                    .background(Theme.surface, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Downloader")
        }
        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 14)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.graphite)
            TextField("Your library or YouTube", text: $query)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit { addRecent(query) }
                .foregroundStyle(Theme.ink)
            if isSearching {
                ProgressView().controlSize(.small)
            } else if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.graphite)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
        .padding(.horizontal, 20).padding(.bottom, 10)
    }

    // MARK: - Content

    @ViewBuilder private var content: some View {
        if query.isEmpty {
            if recents.isEmpty {
                ContentUnavailableView("Find your music", systemImage: "magnifyingglass",
                    description: Text("Search your library — or anything on YouTube."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                recentsList
            }
        } else if !isSearching && songs.isEmpty {
            ContentUnavailableView.search(text: query)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            resultsList
        }
    }

    private var recentsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                HStack {
                    Text("Recent").retro(12, .bold, color: Theme.graphite, tracking: 2)
                    Spacer()
                    Button { clearRecents() } label: {
                        Text("Clear").retro(10, .medium, color: Theme.accent, tracking: 1)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20).padding(.vertical, 10)

                ForEach(recents, id: \.self) { term in
                    Button { query = term } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.arrow.circlepath").foregroundStyle(Theme.graphite)
                            Text(term).retro(14, .medium)
                            Spacer()
                            Image(systemName: "arrow.up.left").font(.footnote).foregroundStyle(Theme.graphite)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 20)
                }
            }
            .padding(.bottom, 140)
        }
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                    HStack(spacing: 0) {
                        Button {
                            addRecent(query)
                            player.play(songs, startAt: index)
                        } label: {
                            SongRow(song: song, isPlaying: player.current?.id == song.id,
                                    favorited: !song.isVirtual && player.isFavorite(song))
                                .padding(.leading, 20).padding(.vertical, 10)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if song.isVirtual {
                            saveControl(for: song).padding(.leading, 12).padding(.trailing, 14)
                        } else {
                            SongMenuButton(song: song).padding(.trailing, 4)
                        }
                    }
                    Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 76)
                }
            }
            .padding(.bottom, 140)
        }
    }

    // MARK: - Recent searches

    private func loadRecents() {
        if let data = UserDefaults.standard.data(forKey: recentsKey),
           let arr = try? JSONDecoder().decode([String].self, from: data) {
            recents = arr
        }
        #if DEBUG
        if recents.isEmpty, ProcessInfo.processInfo.environment["GEETHUB_SEEDRECENTS"] == "1" {
            recents = ["Bir Bahadur", "Coldplay", "Nepali songs", "John Farnham", "Lo-fi"]
        }
        #endif
    }
    private func saveRecents() {
        if let data = try? JSONEncoder().encode(recents) {
            UserDefaults.standard.set(data, forKey: recentsKey)
        }
    }
    private func addRecent(_ q: String) {
        let t = q.trimmingCharacters(in: .whitespaces)
        guard t.count >= 2 else { return }
        recents.removeAll { $0.caseInsensitiveCompare(t) == .orderedSame }
        recents.insert(t, at: 0)
        if recents.count > 12 { recents = Array(recents.prefix(12)) }
        saveRecents()
    }
    private func clearRecents() { recents = []; saveRecents() }

    // MARK: - Save-to-Library + toast

    @ViewBuilder private func saveControl(for song: Song) -> some View {
        if player.savedYouTube.contains(song.id) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
        } else if let pct = player.downloads[song.id] {
            ProgressRing(percent: pct).frame(width: 22, height: 22)
        } else if player.failedDownloads.contains(song.id) {
            Button { Task { await save(song, folder: nil) } } label: {
                Image(systemName: "exclamationmark.arrow.circlepath")
                    .font(.title3).foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        } else if folders.isEmpty {
            Button { Task { await save(song, folder: nil) } } label: {
                Image(systemName: "arrow.down.circle").font(.title3).foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
        } else {
            Menu {
                Button("Library root") { Task { await save(song, folder: nil) } }
                Divider()
                ForEach(folders, id: \.self) { f in
                    Button(f) { Task { await save(song, folder: f) } }
                }
            } label: {
                Image(systemName: "arrow.down.circle").font(.title3).foregroundStyle(Theme.accent)
            }
        }
    }

    @ViewBuilder private var toastView: some View {
        if let toast {
            Text(toast).retro(11, .medium, color: Theme.paper, tracking: 1)
                .padding(.horizontal, 16).padding(.vertical, 11)
                .background(Theme.ink, in: Capsule())
                .padding(.bottom, 120)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Search

    private func scheduleSearch(_ q: String) {
        searchTask?.cancel()
        let text = q.trimmingCharacters(in: .whitespaces)
        guard text.count >= 2 else { songs = []; isSearching = false; return }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let client = session.client else { return }
            isSearching = true
            let result = try? await client.search(text, songCount: 40, ytSource: ytSource)
            guard !Task.isCancelled else { return }
            songs = result?.song ?? []
            isSearching = false
        }
    }

    private func save(_ song: Song, folder: String?) async {
        guard let client = session.client else { return }
        player.startedDownload(song.id)
        do {
            let downloadId = try await client.startSave(youtubeId: song.id, folder: folder)
            let where_ = folder.map { " → \($0)" } ?? ""
            showToast("Saving “\(song.title)”\(where_)")
            guard let downloadId else {
                // Old proxy — no polling available. Optimistically mark done.
                player.finishedDownload(song.id, success: true)
                return
            }
            var errors = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                do {
                    let status = try await client.downloadStatus(downloadId: downloadId)
                    errors = 0
                    if status.state == "done" {
                        player.finishedDownload(song.id, success: true)
                        return
                    }
                    if status.state == "failed" {
                        player.finishedDownload(song.id, success: false)
                        showToast("Download failed")
                        return
                    }
                    player.setDownloadProgress(song.id, percent: status.percent)
                } catch {
                    // Proxy container restart wipes the in-memory DOWNLOADS
                    // dict — status polls come back 404 forever. Give up after
                    // a handful of errors so the ring doesn't spin indefinitely.
                    errors += 1
                    if errors >= 5 {
                        player.finishedDownload(song.id, success: false)
                        return
                    }
                }
            }
        } catch {
            player.finishedDownload(song.id, success: false)
            showToast("Couldn't start the download")
        }
    }

    private func showToast(_ text: String) {
        withAnimation { toast = text }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { toast = nil }
        }
    }
}
