// App-target file. Signed-in shell: 5 tabs + mini now-playing bar + full player.
import SwiftUI
import GeetHubKit

struct MainTabView: View {
    @Environment(Session.self) private var session
    @Environment(ThemeManager.self) private var theme
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var player: PlayerEngine?
    @State private var picker = PlaylistPicker()
    @State private var playlistFavs = PlaylistFavorites()
    @State private var downloads: DownloadsCoordinator?
    @State private var showPlayer = false
    @State private var dockPlayer = false
    @State private var selectedTab = 0

    /// The dock affordance only makes sense on regular-width devices — Mac
    /// Catalyst always, iPad in regular horizontal size class. iPhone is too
    /// narrow to split; it keeps the mini-player + sheet flow.
    private var canDock: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        return hSize == .regular
        #endif
    }

    var body: some View {
        Group {
            if let player, let downloads {
                HStack(spacing: 0) {
                    tabShell(player: player, downloads: downloads)
                        .frame(maxWidth: .infinity)
                    if canDock && dockPlayer {
                        Divider()
                        FullPlayerView(onClose: {
                            withAnimation(.easeInOut(duration: 0.22)) { dockPlayer = false }
                        })
                        .environment(session)
                        .environment(theme)
                        .environment(player)
                        .environment(picker)
                        .environment(playlistFavs)
                        .environment(downloads)
                        .frame(width: 440)
                        .transition(.move(edge: .trailing))
                    }
                }
                .animation(.easeInOut(duration: 0.22), value: dockPlayer)
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
            if downloads == nil, let client = session.client {
                downloads = DownloadsCoordinator(client: client)
            }
            #if DEBUG
            if let t = ProcessInfo.processInfo.environment["GEETHUB_TAB"], let i = Int(t) { selectedTab = i }
            #endif
        }
    }

    @ViewBuilder
    private func tabShell(player: PlayerEngine, downloads: DownloadsCoordinator) -> some View {
        // Native iOS 26: icon-only tabs on iPhone, labelled on iPad/Mac (where
        // iOS 26 renders a sidebar and blank items would look broken).
        // .id(theme.choice) re-tints on accent change.
        let isWide = hSize == .regular
        TabView(selection: $selectedTab) {
            Tab(isWide ? "Home" : "", systemImage: "house", value: 0) {
                HomeView(onSelectTab: { selectedTab = $0 }).id(theme.choice)
            }
            Tab(isWide ? "Library" : "", systemImage: "square.stack", value: 1) {
                LibraryView().id(theme.choice)
            }
            Tab(isWide ? "Favourites" : "", systemImage: "heart", value: 2) {
                FavoritesView().id(theme.choice)
            }
            Tab(isWide ? "Search" : "", systemImage: "magnifyingglass", value: 3) {
                SearchView().id(theme.choice)
            }
            Tab(isWide ? "Settings" : "", systemImage: "gearshape", value: 4) {
                SettingsView().id(theme.choice)
            }
        }
        // iOS 26 has a minimising tab bar + native bottom-accessory slot for
        // the mini player. On Mac Catalyst neither exists, so we render the
        // mini player ourselves via overlay. On both platforms we hide the
        // mini player when the docked pane is showing (it'd be redundant).
        #if !targetEnvironment(macCatalyst)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            if !(canDock && dockPlayer) {
                NowPlayingAccessory(
                    onTap: { showPlayer = true },
                    onDock: canDock ? { withAnimation(.easeInOut(duration: 0.22)) { dockPlayer = true } } : nil
                )
            }
        }
        #else
        .overlay(alignment: .bottom) {
            if !dockPlayer {
                NowPlayingAccessory(
                    onTap: { showPlayer = true },
                    onDock: { withAnimation(.easeInOut(duration: 0.22)) { dockPlayer = true } }
                )
                .environment(player)
                .environment(picker)
                .environment(playlistFavs)
                .frame(height: 56)
                .padding(.horizontal, 16)
                .background(.regularMaterial)
                .overlay(Rectangle().fill(Theme.hairline).frame(height: 1), alignment: .top)
            }
        }
        #endif
        .environment(player)
        .environment(picker)
        .environment(playlistFavs)
        .environment(downloads)
        .tint(theme.accent)
        // Full player as a modal (fullScreenCover on iPhone/iPad,
        // sheet on Mac Catalyst where fullScreenCover crashed on env resolution).
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
