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

struct SettingsView: View {
    @Environment(Session.self) private var session
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Settings").retro(30, .bold, tracking: 1)
                        .padding(.horizontal, 20).padding(.top, 8)

                    appearance

                    VStack(spacing: 0) {
                        if let host = session.client?.credentials.baseURL.host {
                            settingRow("Server", host)
                            divider
                        }
                        if let user = session.client?.credentials.username {
                            settingRow("User", user)
                            divider
                        }
                        settingRow("Version", "0.1")
                    }
                    .background(Theme.surface)
                    .overlay(Rectangle().strokeBorder(Theme.hairline, lineWidth: 1))
                    .padding(.horizontal, 20)

                    Button { session.signOut() } label: {
                        Text("Sign out").retro(14, .semibold, color: .white, tracking: 2)
                            .frame(maxWidth: .infinity).padding(.vertical, 14).background(Theme.accent)
                    }
                    .padding(.horizontal, 20).padding(.top, 8)
                }
                .padding(.bottom, 120)
            }
            .paperBackground()
            .navigationBarHidden(true)
        }
    }

    private var appearance: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Accent color").retro(12, .medium, color: Theme.graphite, tracking: 1.5)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(AccentChoice.allCases) { choice in
                        Button { theme.choice = choice } label: {
                            Circle().fill(choice.color).frame(width: 34, height: 34)
                                .overlay(
                                    Circle().strokeBorder(Theme.ink, lineWidth: theme.choice == choice ? 2.5 : 0)
                                        .padding(-4)
                                )
                                .overlay(
                                    Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white)
                                        .opacity(theme.choice == choice ? 1 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4).padding(.horizontal, 2)
            }
        }
        .padding(18)
        .background(Theme.surface)
        .overlay(Rectangle().strokeBorder(Theme.hairline, lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private var divider: some View { Rectangle().fill(Theme.hairline).frame(height: 1) }

    private func settingRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).retro(12, .medium, color: Theme.graphite, tracking: 1.5)
            Spacer()
            Text(value).font(.system(.subheadline, design: .monospaced)).foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 16).padding(.vertical, 15)
    }
}
