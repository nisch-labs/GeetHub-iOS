// App-target file. Signed-in shell: 5 tabs + mini now-playing bar + full player.
import SwiftUI
import GeetHubKit

struct MainTabView: View {
    @Environment(Session.self) private var session
    @State private var player: PlayerEngine?
    @State private var showPlayer = false
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if let player {
                ZStack(alignment: .bottom) {
                    // Native iOS 26 Liquid Glass tab bar, icon-only (no labels).
                    TabView(selection: $selectedTab) {
                        HomeView(onSelectTab: { selectedTab = $0 }).tag(0).tabItem { Image(systemName: "house") }
                        LibraryView().tag(1).tabItem { Image(systemName: "square.stack") }
                        FavoritesView().tag(2).tabItem { Image(systemName: "heart") }
                        SearchView().tag(3).tabItem { Image(systemName: "magnifyingglass") }
                        SettingsView().tag(4).tabItem { Image(systemName: "gearshape") }
                    }
                    NowPlayingBar(onTap: { showPlayer = true })
                        .padding(.bottom, 64)   // float above the glass bar
                }
                .environment(player)
                .tint(Theme.teal)
                .fullScreenCover(isPresented: $showPlayer) { FullPlayerView().environment(player) }
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

struct SettingsView: View {
    @Environment(Session.self) private var session

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Settings").retro(30, .bold, tracking: 1)
                        .padding(.horizontal, 20).padding(.top, 8)

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
                            .frame(maxWidth: .infinity).padding(.vertical, 14).background(Theme.teal)
                    }
                    .padding(.horizontal, 20).padding(.top, 8)
                }
                .padding(.bottom, 120)
            }
            .paperBackground()
            .navigationBarHidden(true)
        }
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
