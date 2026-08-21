// App-target file. Live search — real library hits + YouTube results (from the
// proxy), tap to play, and Save-to-Library on YouTube rows.
import SwiftUI
import GeetHubKit

struct SearchView: View {
    @Environment(Session.self) private var session
    @Environment(PlayerEngine.self) private var player

    @State private var query = ""
    @State private var songs: [Song] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var saved: Set<String> = []
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                    HStack {
                        Button {
                            player.play(songs, startAt: index)
                        } label: {
                            SongRow(song: song, isPlaying: player.current?.id == song.id)
                                .foregroundStyle(.primary)
                        }
                        if song.isYouTube {
                            Spacer(minLength: 4)
                            saveButton(for: song)
                        }
                    }
                }
                if !isSearching && songs.isEmpty && !query.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Search")
            .overlay(alignment: .top) { if isSearching { ProgressView().padding(.top, 4) } }
            .overlay(alignment: .bottom) { toastView }
        }
        .searchable(text: $query, prompt: "Songs in your library or on YouTube")
        .onChange(of: query) { _, q in scheduleSearch(q) }
    }

    @ViewBuilder private func saveButton(for song: Song) -> some View {
        if saved.contains(song.id) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        } else {
            Button {
                Task { await save(song) }
            } label: {
                Image(systemName: "arrow.down.circle").font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
        }
    }

    @ViewBuilder private var toastView: some View {
        if let toast {
            Text(toast)
                .font(.callout).padding(.horizontal, 16).padding(.vertical, 10)
                .background(.thinMaterial, in: Capsule())
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func scheduleSearch(_ q: String) {
        searchTask?.cancel()
        let text = q.trimmingCharacters(in: .whitespaces)
        guard text.count >= 2 else { songs = []; isSearching = false; return }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))   // debounce
            guard !Task.isCancelled, let client = session.client else { return }
            isSearching = true
            let result = try? await client.search(text, songCount: 40)
            guard !Task.isCancelled else { return }
            songs = result?.song ?? []
            isSearching = false
        }
    }

    private func save(_ song: Song) async {
        guard let client = session.client else { return }
        do {
            try await client.saveToLibrary(youtubeId: song.id)
            saved.insert(song.id)
            showToast("Saving “\(song.title)” to your library…")
        } catch {
            showToast("Couldn't start download.")
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
