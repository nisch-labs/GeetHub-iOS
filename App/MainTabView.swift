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
                ZStack(alignment: .bottom) {
                    // Native iOS 26 Liquid Glass tab bar, icon-only (no labels).
                    // .id(theme.choice) on each tab's content re-tints it when the
                    // accent changes, without disturbing the TabView selection.
                    TabView(selection: $selectedTab) {
                        HomeView(onSelectTab: { selectedTab = $0 }).id(theme.choice).tag(0).tabItem { Image(systemName: "house") }
                        LibraryView().id(theme.choice).tag(1).tabItem { Image(systemName: "square.stack") }
                        FavoritesView().id(theme.choice).tag(2).tabItem { Image(systemName: "heart") }
                        SearchView().id(theme.choice).tag(3).tabItem { Image(systemName: "magnifyingglass") }
                        SettingsView().id(theme.choice).tag(4).tabItem { Image(systemName: "gearshape") }
                    }
                    NowPlayingBar(onTap: { showPlayer = true })
                        .padding(.bottom, 64)   // float above the glass bar
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
