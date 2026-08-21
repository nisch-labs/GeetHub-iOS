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
                MainTabView()
            } else {
                LoginView()
            }
        }
        .tint(Theme.teal)
        .preferredColorScheme(.light)   // the vinyl look is intentionally paper-light
        .task { await start() }
    }

    private func start() async {
        session.restore()
        #if DEBUG
        // Convenience for simulator runs: auto-connect from launch env vars
        // (SIMCTL_CHILD_GEETHUB_URL / _USER / _PASS). Never used in release.
        let env = ProcessInfo.processInfo.environment
        if !session.isConnected,
           let url = env["GEETHUB_URL"], let u = env["GEETHUB_USER"], let p = env["GEETHUB_PASS"] {
            await session.connect(urlString: url, username: u, password: p)
        }
        #endif
    }
}
