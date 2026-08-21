// App-target file. Signed-in shell: tabs + mini now-playing bar + full player.
import SwiftUI
import GeetHubKit

struct MainTabView: View {
    @Environment(Session.self) private var session
    @State private var player: PlayerEngine?
    @State private var showPlayer = false

    var body: some View {
        Group {
            if let player {
                ZStack(alignment: .bottom) {
                    TabView {
                        LibraryView()
                            .tabItem { Label("Library", systemImage: "square.stack") }
                        SearchView()
                            .tabItem { Label("Search", systemImage: "magnifyingglass") }
                        AccountView()
                            .tabItem { Label("Account", systemImage: "person.crop.circle") }
                    }
                    NowPlayingBar(onTap: { showPlayer = true })
                        .padding(.bottom, 50)   // sit just above the tab bar
                }
                .environment(player)
                .tint(Theme.teal)
                .sheet(isPresented: $showPlayer) {
                    FullPlayerView().environment(player)
                }
                .task { await demoIfRequested(player) }
            } else {
                ProgressView().paperBackground()
            }
        }
        .task {
            if player == nil, let client = session.client {
                player = PlayerEngine(client: client)
            }
        }
    }

    private func demoIfRequested(_ player: PlayerEngine) async {
        #if DEBUG
        guard ProcessInfo.processInfo.environment["GEETHUB_DEMO"] == "play",
              !player.hasTrack, let client = session.client else { return }
        if let album = (try? await client.albumList(type: "alphabeticalByName", size: 20))?.first,
           let songs = (try? await client.album(id: album.id))?.song, !songs.isEmpty {
            player.play(songs, startAt: 0)
            try? await Task.sleep(for: .seconds(2))
            showPlayer = true
        }
        #endif
    }
}

struct AccountView: View {
    @Environment(Session.self) private var session

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let host = session.client?.credentials.baseURL.host {
                        row("Server", host)
                    }
                    if let user = session.client?.credentials.username {
                        row("User", user)
                    }
                }
                Section {
                    Button { session.signOut() } label: {
                        Text("Sign out").retro(14, .medium, color: Theme.teal)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .paperBackground()
            .navigationTitle("Account")
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).retro(12, .medium, color: Theme.graphite, tracking: 1.5)
            Spacer()
            Text(value).font(.system(.subheadline, design: .monospaced)).foregroundStyle(Theme.ink)
        }
        .listRowBackground(Theme.surface)
    }
}
