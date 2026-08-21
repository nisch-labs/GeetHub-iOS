// App-target file (SwiftUI). Add to the Xcode app target.
import SwiftUI
import GeetHubKit

/// Top-level switch: show the login screen until a server is connected, then the
/// library. Restores a saved server on launch.
struct RootView: View {
    @Environment(Session.self) private var session

    var body: some View {
        Group {
            if session.isConnected {
                // TODO: LibraryView() — browse / search / now-playing (next up).
                ConnectedPlaceholderView()
            } else {
                LoginView()
            }
        }
        .task { session.restore() }
    }
}

/// Temporary stand-in until the library UI is built.
private struct ConnectedPlaceholderView: View {
    @Environment(Session.self) private var session

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Connected 🎵").font(.title2.bold())
            if let host = session.client?.credentials.baseURL.host {
                Text(host).foregroundStyle(.secondary)
            }
            Button("Sign out", role: .destructive) { session.signOut() }
                .buttonStyle(.bordered)
        }
        .padding()
    }
}
