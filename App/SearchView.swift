// App-target file. Live search — library + YouTube results, play, Save-to-Library.
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
                    HStack(spacing: 8) {
                        Button { player.play(songs, startAt: index) } label: {
                            SongRow(song: song, isPlaying: player.current?.id == song.id)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if song.isYouTube { saveButton(for: song) }
                    }
                    .listRowBackground(Theme.surface)
                    .listRowSeparatorTint(Theme.hairline)
                }
                if !isSearching && songs.isEmpty && !query.isEmpty {
                    ContentUnavailableView.search(text: query).listRowBackground(Theme.paper)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .paperBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { Text("Search").retro(14, .semibold, tracking: 2) }
            }
            .overlay(alignment: .top) { if isSearching { ProgressView().padding(.top, 4) } }
            .overlay(alignment: .bottom) { toastView }
        }
        .tint(Theme.teal)
        .searchable(text: $query, prompt: "Your library or YouTube")
        .onChange(of: query) { _, q in scheduleSearch(q) }
    }

    @ViewBuilder private func saveButton(for song: Song) -> some View {
        if saved.contains(song.id) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.teal)
        } else {
            Button { Task { await save(song) } } label: {
                Image(systemName: "arrow.down.circle").font(.title3).foregroundStyle(Theme.teal)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder private var toastView: some View {
        if let toast {
            Text(toast).retro(11, .medium, color: .white, tracking: 1)
                .padding(.horizontal, 16).padding(.vertical, 11)
                .background(Theme.ink, in: Capsule())
                .padding(.bottom, 76)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func scheduleSearch(_ q: String) {
        searchTask?.cancel()
        let text = q.trimmingCharacters(in: .whitespaces)
        guard text.count >= 2 else { songs = []; isSearching = false; return }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
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
            showToast("Saving “\(song.title)” to your library")
        } catch {
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
