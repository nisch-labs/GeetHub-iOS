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
                    TabView(selection: $selectedTab) {
                        HomeView().tag(0).toolbar(.hidden, for: .tabBar)
                        LibraryView().tag(1).toolbar(.hidden, for: .tabBar)
                        FavoritesView().tag(2).toolbar(.hidden, for: .tabBar)
                        SearchView().tag(3).toolbar(.hidden, for: .tabBar)
                        SettingsView().tag(4).toolbar(.hidden, for: .tabBar)
                    }
                    VStack(spacing: 0) {
                        NowPlayingBar(onTap: { showPlayer = true })
                        CustomTabBar(selection: $selectedTab)
                    }
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

/// Minimal icon-only bottom bar — small icons, no labels.
struct CustomTabBar: View {
    @Binding var selection: Int
    private let items = ["house", "square.stack", "heart", "magnifyingglass", "gearshape"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, icon in
                Button { selection = index } label: {
                    Image(systemName: icon)
                        .font(.system(size: 19))
                        .foregroundStyle(selection == index ? Theme.teal : Theme.graphite)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(Theme.surface.ignoresSafeArea(edges: .bottom))
        .overlay(Rectangle().fill(Theme.hairline).frame(height: 1), alignment: .top)
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
