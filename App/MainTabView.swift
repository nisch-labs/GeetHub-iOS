// App-target file. Signed-in shell: 5 tabs + mini now-playing bar + full player.
import SwiftUI
import GeetHubKit

struct MainTabView: View {
    @Environment(Session.self) private var session
    @Environment(ThemeManager.self) private var theme
    @State private var player: PlayerEngine?
    @State private var picker = PlaylistPicker()
    @State private var showPlayer = false
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if let player {
                // Native iOS 26: labeled tabs, a Search role tab, a now-playing
                // bottom accessory, and a tab bar that minimizes on scroll — the
                // Apple Music behaviour. .id(theme.choice) re-tints on accent change.
                TabView(selection: $selectedTab) {
                    Tab("", systemImage: "house", value: 0) {
                        HomeView(onSelectTab: { selectedTab = $0 }).id(theme.choice)
                    }
                    Tab("", systemImage: "square.stack", value: 1) {
                        LibraryView().id(theme.choice)
                    }
                    Tab("", systemImage: "magnifyingglass", value: 3) {
                        SearchView().id(theme.choice)
                    }
                    Tab("", systemImage: "gearshape", value: 4) {
                        SettingsView().id(theme.choice)
                    }
                    Tab("", systemImage: "heart", value: 2) {
                        FavoritesView().id(theme.choice)
                    }
                }
                .tabBarMinimizeBehavior(.onScrollDown)
                .tabViewBottomAccessory {
                    NowPlayingAccessory(onTap: { showPlayer = true })
                }
                .environment(player)
                .environment(picker)
                .tint(theme.accent)
                .fullScreenCover(isPresented: $showPlayer) {
                    FullPlayerView().environment(player).environment(picker)
                }
                .sheet(item: $picker.song) { song in
                    AddToPlaylistSheet(song: song)
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
            #if DEBUG
            if let t = ProcessInfo.processInfo.environment["GEETHUB_TAB"], let i = Int(t) { selectedTab = i }
            #endif
        }
    }

    private func demoIfRequested(_ player: PlayerEngine) async {
        #if DEBUG
        let demo = ProcessInfo.processInfo.environment["GEETHUB_DEMO"]
        guard demo == "play" || demo == "playonly",
              !player.hasTrack, let client = session.client else { return }
        if let album = (try? await client.albumList(type: "alphabeticalByName", size: 20))?.first,
           let songs = (try? await client.album(id: album.id))?.song, !songs.isEmpty {
            player.play(songs, startAt: 0)
            if demo == "play" {
                try? await Task.sleep(for: .seconds(2))
                showPlayer = true
            }
        }
        #endif
    }
}

// SettingsView + its detail screens live in Settings.swift.
