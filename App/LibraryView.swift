// App-target file. Browse the library — a wall of album sleeves.
import SwiftUI
import GeetHubKit

struct LibraryView: View {
    @Environment(Session.self) private var session
    @State private var albums: [Album] = []
    @State private var isLoading = true
    @State private var error: String?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 20)]

    var body: some View {
        NavigationStack {
            ScrollView {
                header
                if isLoading {
                    ProgressView().padding(.top, 60)
                } else if let error {
                    ContentUnavailableView("Can't reach your library", systemImage: "wifi.slash", description: Text(error))
                        .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(albums) { album in
                            NavigationLink(value: album) {
                                AlbumCell(album: album)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                }
            }
            .paperBackground()
            .navigationBarHidden(true)
            .navigationDestination(for: Album.self) { AlbumDetailView(album: $0) }
        }
        .task { await load() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Library").retro(34, .bold, tracking: 1)
            Spacer()
            Text("\(albums.count) albums")
                .retro(11, .light, color: Theme.graphite, tracking: 1.5)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
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
