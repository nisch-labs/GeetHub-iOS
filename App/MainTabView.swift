// App-target file. Signed-in shell: 5 tabs + mini now-playing bar + full player.
import SwiftUI
import GeetHubKit

struct MainTabView: View {
    @Environment(Session.self) private var session
    @Environment(ThemeManager.self) private var theme
    @State private var player: PlayerEngine?
    @State private var picker = PlaylistPicker()
    @State private var playlistFavs = PlaylistFavorites()
    @State private var showPlayer = false
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if let player {
                // Native iOS 26: labeled tabs, a Search role tab, a now-playing
                // bottom accessory, and a tab bar that minimizes on scroll — the
                // Apple Music behaviour. .id(theme.choice) re-tints on accent change.
                TabView(selection: $selectedTab) {
                    // Labels are needed for iPad / Mac Catalyst — iOS 26
                    // TabView renders tabs as a sidebar/toolbar there, and
                    // sidebar items must have a text label. On iPhone the
                    // native tab bar shows icon-only when the label is short.
                    Tab("Home", systemImage: "house", value: 0) {
                        HomeView(onSelectTab: { selectedTab = $0 }).id(theme.choice)
                    }
                    Tab("Library", systemImage: "square.stack", value: 1) {
                        LibraryView().id(theme.choice)
                    }
                    Tab("Favourites", systemImage: "heart", value: 2) {
                        FavoritesView().id(theme.choice)
                    }
                    Tab("Search", systemImage: "magnifyingglass", value: 3) {
                        SearchView().id(theme.choice)
                    }
                    Tab("Settings", systemImage: "gearshape", value: 4) {
                        SettingsView().id(theme.choice)
                    }
                }
                // iOS 26 has a minimising tab bar + native bottom-accessory
                // slot. On Mac Catalyst neither exists, so we render the mini
                // player ourselves via overlay. Environment is injected right
                // on the accessory to avoid a SwiftUI env-propagation crash we
                // saw when relying on inherited environments through
                // safeAreaInset on Catalyst.
                #if !targetEnvironment(macCatalyst)
                .tabBarMinimizeBehavior(.onScrollDown)
                .tabViewBottomAccessory {
                    NowPlayingAccessory(onTap: { showPlayer = true })
                }
                #else
                .overlay(alignment: .bottom) {
                    NowPlayingAccessory(onTap: { showPlayer = true })
                        .environment(player)
                        .environment(picker)
                        .environment(playlistFavs)
                        .frame(height: 56)
                        .padding(.horizontal, 16)
                        .background(.regularMaterial)
                        .overlay(Rectangle().fill(Theme.hairline).frame(height: 1), alignment: .top)
                }
                #endif
                .environment(player)
                .environment(picker)
                .environment(playlistFavs)
                .tint(theme.accent)
                // Full player: fullScreenCover on iPhone/iPad; on Mac Catalyst
                // that presentation style is unreliable and was crashing during
                // env resolution — .sheet is the native Mac modal anyway.
                #if targetEnvironment(macCatalyst)
                .sheet(isPresented: $showPlayer) {
                    FullPlayerView()
                        .environment(session)
                        .environment(theme)
                        .environment(player)
                        .environment(picker)
                        .environment(playlistFavs)
                        .frame(minWidth: 420, minHeight: 640)
                }
                #else
                .fullScreenCover(isPresented: $showPlayer) {
                    FullPlayerView().environment(player).environment(picker)
                }
                #endif
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
