// App-target file. Browse the library — albums grid (v1).
import SwiftUI
import GeetHubKit

struct LibraryView: View {
    @Environment(Session.self) private var session
    @State private var albums: [Album] = []
    @State private var isLoading = true
    @State private var error: String?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if let error {
                    ContentUnavailableView("Couldn't load library", systemImage: "wifi.slash", description: Text(error))
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(albums) { album in
                                NavigationLink(value: album) {
                                    AlbumCell(album: album).foregroundStyle(.primary)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Library")
            .navigationDestination(for: Album.self) { AlbumDetailView(album: $0) }
        }
        .task { await load() }
    }

    private func load() async {
        guard let client = session.client else { return }
        do {
            albums = try await client.albumList(type: "alphabeticalByName", size: 200)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
