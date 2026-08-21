// App-target file. The signed-in shell: tabs + a mini now-playing bar.
import SwiftUI
import GeetHubKit

struct MainTabView: View {
    @Environment(Session.self) private var session
    @State private var player: PlayerEngine?

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
                    NowPlayingBar()
                        .padding(.bottom, 50)   // sit just above the tab bar
                }
                .environment(player)
            } else {
                ProgressView()
            }
        }
        .task {
            if player == nil, let client = session.client {
                player = PlayerEngine(client: client)
            }
        }
    }
}

struct AccountView: View {
    @Environment(Session.self) private var session

    var body: some View {
        NavigationStack {
            List {
                if let host = session.client?.credentials.baseURL.host {
                    LabeledContent("Server", value: host)
                }
                if let user = session.client?.credentials.username {
                    LabeledContent("User", value: user)
                }
                Button("Sign out", role: .destructive) { session.signOut() }
            }
            .navigationTitle("Account")
        }
    }
}
