// App-target file (SwiftUI). Add to the Xcode app target as the @main entry.
// The Xcode project depends on the local GeetHubKit Swift Package.
import SwiftUI
import GeetHubKit

@main
struct GeetHubApp: App {
    @State private var session = Session()
    @State private var theme = ThemeManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(theme)
        }
    }
}
