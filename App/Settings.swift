// App-target file. Settings — a list of categories, each opening a detail page.
import SwiftUI
import GeetHubKit

private let recentSearchesKey = "recentSearches"

private var appVersion: String {
    (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
}

struct SettingsView: View {
    @Environment(Session.self) private var session
    @Environment(PlayerEngine.self) private var player
    @Environment(ThemeManager.self) private var theme
    @AppStorage("ytSearchSource") private var ytSource: String = "ytmusic"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    Text("Settings").retro(20, .bold, tracking: 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 4)

                    card("cylinder.split.1x2.fill", "Server & Account",
                         session.client?.credentials.baseURL.host ?? "Not signed in") {
                        ServerAccountSettings()
                    }
                    card("paintpalette.fill", "Appearance & Layout",
                         "\(theme.scheme.label) · \(theme.choice.label)") {
                        AppearanceSettings()
                    }
                    card("magnifyingglass", "Search",
                         ytSource == "youtube" ? "YouTube" : "YouTube Music") {
                        SearchSourceSettings()
                    }
                    card("folder.fill", "Storage",
                         "Caches, recent searches, history") { StorageSettings() }
                    card("questionmark.circle.fill", "Help & Welcome Guide",
                         "Gestures, features, and tips") { HelpSettings() }

                    Text("Geet-Hub · Version \(appVersion)")
                        .retro(9, .light, color: Theme.graphite, tracking: 1.5)
                        .padding(.top, 14)
                }
                .padding(.bottom, 130)
            }
            .paperBackground()
            .navigationBarHidden(true)
        }
    }

    private func card<D: View>(_ icon: String, _ title: String, _ subtitle: String,
                               @ViewBuilder destination: @escaping () -> D) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 15)).foregroundStyle(Theme.accent).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).retro(13, .semibold)
                    Text(subtitle).retro(8, .light, color: Theme.graphite, tracking: 0.5).lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.graphite)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }
}

@MainActor private func detailTitle(_ title: String) -> some ToolbarContent {
    ToolbarItem(placement: .principal) { Text(title).retro(12, .semibold, tracking: 2).lineLimit(1) }
}

// MARK: - Server & Account

struct ServerAccountSettings: View {
    @Environment(Session.self) private var session
    @State private var revealServer = false
    @State private var revealUser = false
    @State private var confirmSignOut = false
    @State private var showAdd = false
    @State private var showEdit = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 0) {
                    if let host = session.client?.credentials.baseURL.host {
                        secretRow("Server", host, revealed: $revealServer); divider
                    }
                    if let user = session.client?.credentials.username {
                        secretRow("User", user, revealed: $revealUser); divider
                    }
                    row("Version", appVersion)
                }
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
                .padding(.horizontal, 20).padding(.top, 12)

                VStack(spacing: 0) {
                    actionRow("plus.circle", "Add Server") { showAdd = true }
                    divider
                    switchServerRow
                    divider
                    actionRow("pencil", "Edit Current Server", enabled: session.activeServer != nil) {
                        showEdit = true
                    }
                }
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
                .padding(.horizontal, 20)

                Button { confirmSignOut = true } label: {
                    Text("Log out").retro(14, .semibold, color: .white, tracking: 2)
                        .frame(maxWidth: .infinity).padding(.vertical, 14).background(Theme.accent)
                }
                .padding(.horizontal, 20)
                .confirmationDialog("Log out of Geet-Hub?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                    Button("Log out", role: .destructive) { session.signOut() }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Every saved server will be cleared from this device.")
                }
            }
            .padding(.bottom, 40)
        }
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { detailTitle("Server & Account") }
        .sheet(isPresented: $showAdd) {
            AddServerSheet().environment(session)
        }
        .sheet(isPresented: $showEdit) {
            if let active = session.activeServer {
                EditServerSheet(server: active).environment(session)
            }
        }
    }

    private var divider: some View { Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 16) }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).retro(12, .medium, color: Theme.graphite, tracking: 1.5)
            Spacer()
            Text(value).font(.system(.subheadline, design: .monospaced)).foregroundStyle(Theme.ink).lineLimit(1)
        }
        .padding(.horizontal, 16).padding(.vertical, 15)
    }

    private func secretRow(_ label: String, _ value: String,
                           revealed: Binding<Bool>) -> some View {
        HStack {
            Text(label).retro(12, .medium, color: Theme.graphite, tracking: 1.5)
            Spacer()
            Text(revealed.wrappedValue ? value : String(repeating: "•", count: min(10, max(6, value.count))))
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Button { revealed.wrappedValue.toggle() } label: {
                Image(systemName: revealed.wrappedValue ? "eye.slash" : "eye")
                    .foregroundStyle(Theme.graphite)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16).padding(.vertical, 15)
    }

    private func actionRow(_ icon: String, _ title: String,
                           enabled: Bool = true,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(enabled ? Theme.accent : Theme.graphite).frame(width: 22)
                Text(title).retro(13, .medium, color: enabled ? Theme.ink : Theme.graphite, tracking: 0.5)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.graphite)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    @ViewBuilder private var switchServerRow: some View {
        let others = session.servers.filter { $0.id != session.activeId }
        if others.isEmpty {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.2.swap").foregroundStyle(Theme.graphite).frame(width: 22)
                Text("Switch Server").retro(13, .medium, color: Theme.graphite, tracking: 0.5)
                Spacer()
                Text("Only one saved").retro(9, .light, color: Theme.graphite, tracking: 1)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
        } else {
            Menu {
                ForEach(others) { s in
                    Button {
                        session.switchServer(id: s.id)
                    } label: {
                        Label(s.label, systemImage: "server.rack")
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.2.swap").foregroundStyle(Theme.accent).frame(width: 22)
                    Text("Switch Server").retro(13, .medium, color: Theme.ink, tracking: 0.5)
                    Spacer()
                    Text("\(others.count) other\(others.count == 1 ? "" : "s")")
                        .retro(9, .light, color: Theme.graphite, tracking: 1)
                    Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(Theme.graphite)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .contentShape(Rectangle())
            }
        }
    }
}

// MARK: - Add / Edit sheets

private struct ServerFormFields: View {
    let title: String
    @Binding var label: String
    @Binding var urlString: String
    @Binding var username: String
    @Binding var password: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 22) {
            Text(title).retro(22, .bold, tracking: 1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.top, 8)

            VStack(spacing: 0) {
                fieldRow("Label", text: $label, keyboard: .default); line
                fieldRow("Server", text: $urlString, keyboard: .URL); line
                fieldRow("User", text: $username, keyboard: .default); line
                fieldRow("Password", text: $password, secure: true, keyboard: .default)
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
            .padding(.horizontal, 20)

            if let message {
                Text(message).retro(11, .regular, color: Theme.accent, tracking: 1)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
    }

    private var line: some View { Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 100) }

    private func fieldRow(_ label: String, text: Binding<String>,
                          secure: Bool = false, keyboard: UIKeyboardType) -> some View {
        HStack(spacing: 12) {
            Text(label).retro(11, .medium, color: Theme.graphite, tracking: 1.5)
                .frame(width: 82, alignment: .leading)
            Group {
                if secure {
                    SecureField("", text: text)
                } else {
                    TextField("", text: text)
                        .keyboardType(keyboard)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 16).padding(.vertical, 15)
    }
}

struct AddServerSheet: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var urlString = ""
    @State private var username = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                ServerFormFields(title: "Add Server",
                                 label: $label, urlString: $urlString,
                                 username: $username, password: $password,
                                 message: error)
                    .padding(.top, 8)
                Button(action: save) {
                    Group {
                        if busy { ProgressView().tint(.white) }
                        else { Text("Add & switch").retro(14, .semibold, color: .white, tracking: 2) }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(canSubmit ? Theme.accent : Theme.graphite)
                }
                .disabled(!canSubmit || busy)
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 40)
            }
            .paperBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private var canSubmit: Bool { !urlString.isEmpty && !username.isEmpty }

    private func save() {
        busy = true
        error = nil
        Task {
            let ok = await session.connect(urlString: urlString, username: username,
                                           password: password,
                                           label: label.isEmpty ? nil : label)
            busy = false
            if ok {
                dismiss()
            } else if case .failed(let m) = session.state {
                error = m
            } else {
                error = "Couldn't add that server."
            }
        }
    }
}

struct EditServerSheet: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    let server: SavedServer

    @State private var label: String
    @State private var urlString: String
    @State private var username: String
    @State private var password: String
    @State private var busy = false
    @State private var error: String?
    @State private var confirmRemove = false

    init(server: SavedServer) {
        self.server = server
        _label = State(initialValue: server.label)
        _urlString = State(initialValue: server.credentials.baseURL.absoluteString)
        _username = State(initialValue: server.credentials.username)
        // Password field starts empty and only updates if the user types
        // something — a common pattern that avoids re-persisting the same
        // password every save and hides the existing one in the form.
        _password = State(initialValue: "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                ServerFormFields(title: "Edit Server",
                                 label: $label, urlString: $urlString,
                                 username: $username, password: $password,
                                 message: error)
                    .padding(.top, 8)

                if password.isEmpty {
                    Text("Leave password blank to keep the current one.")
                        .retro(9, .light, color: Theme.graphite, tracking: 1)
                        .padding(.horizontal, 20).padding(.top, 8)
                }

                Button(action: save) {
                    Group {
                        if busy { ProgressView().tint(.white) }
                        else { Text("Save changes").retro(14, .semibold, color: .white, tracking: 2) }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(canSubmit ? Theme.accent : Theme.graphite)
                }
                .disabled(!canSubmit || busy)
                .padding(.horizontal, 20).padding(.top, 16)

                Button { confirmRemove = true } label: {
                    Text("Remove This Server").retro(12, .medium, color: .red, tracking: 1.5)
                }
                .buttonStyle(.plain)
                .padding(.top, 18).padding(.bottom, 40)
                .confirmationDialog("Remove \"\(server.label)\"?",
                                    isPresented: $confirmRemove, titleVisibility: .visible) {
                    Button("Remove", role: .destructive) {
                        session.removeServer(id: server.id)
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Its credentials will be forgotten from this device.")
                }
            }
            .paperBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private var canSubmit: Bool { !urlString.isEmpty && !username.isEmpty }

    private func save() {
        busy = true
        error = nil
        Task {
            let effectivePassword = password.isEmpty ? server.credentials.password : password
            let ok = await session.updateServer(id: server.id,
                                                label: label,
                                                urlString: urlString,
                                                username: username,
                                                password: effectivePassword)
            busy = false
            if ok { dismiss() }
            else { error = "Server rejected those details." }
        }
    }
}

// MARK: - Appearance & Layout

struct AppearanceSettings: View {
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Appearance").retro(12, .medium, color: Theme.graphite, tracking: 1.5)
                        .padding(.horizontal, 4)
                    HStack(spacing: 10) {
                        ForEach(ColorSchemeChoice.allCases) { option in
                            let selected = theme.scheme == option
                            Button { theme.scheme = option } label: {
                                Text(option.label)
                                    .retro(12, .semibold,
                                           color: selected ? .white : Theme.ink,
                                           tracking: 1.5)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(selected ? Theme.accent : Theme.surface,
                                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(selected ? Theme.accent : Theme.hairline, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(18)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Accent color").retro(12, .medium, color: Theme.graphite, tracking: 1.5)
                        .padding(.horizontal, 4)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(AccentChoice.allCases) { choice in
                                Button { theme.choice = choice } label: {
                                    Circle().fill(choice.color).frame(width: 36, height: 36)
                                        .overlay(Circle().strokeBorder(Theme.ink, lineWidth: theme.choice == choice ? 2.5 : 0).padding(-4))
                                        .overlay(Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.white).opacity(theme.choice == choice ? 1 : 0))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4).padding(.horizontal, 2)
                    }
                }
                .padding(18)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
            }
            .padding(.horizontal, 20).padding(.top, 12)
        }
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { detailTitle("Appearance & Layout") }
    }
}

// MARK: - Search source

struct SearchSourceSettings: View {
    @AppStorage("ytSearchSource") private var ytSource: String = "ytmusic"

    private struct Option: Identifiable {
        let id: String
        let label: String
        let blurb: String
    }
    private let options: [Option] = [
        .init(id: "ytmusic", label: "YouTube Music",
              blurb: "Song-only results with real artist / album metadata. Cleaner. Occasionally misses obscure uploads."),
        .init(id: "youtube", label: "YouTube",
              blurb: "Full site search. Broader coverage — also includes lyric videos, karaoke and covers.")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(options) { opt in
                    let selected = ytSource == opt.id
                    Button { ytSource = opt.id } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                                .font(.title3).foregroundStyle(selected ? Theme.accent : Theme.graphite)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(opt.label).retro(13, .semibold)
                                Text(opt.blurb).font(.footnote).foregroundStyle(Theme.graphite)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(16)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(selected ? Theme.accent : Theme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                Text("The Search tab has a quick toggle for the same setting.")
                    .retro(9, .light, color: Theme.graphite, tracking: 1.5)
                    .padding(.top, 10)
            }
            .padding(.horizontal, 20).padding(.top, 12)
        }
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { detailTitle("Search") }
    }
}

// MARK: - Storage

struct StorageSettings: View {
    @Environment(PlayerEngine.self) private var player
    @State private var recentSearchesCount = 0
    @State private var cacheBytes = 0
    @State private var pending: Action?

    private enum Action: Identifiable {
        case recentSearches, recentlyPlayed, artworkCache, youtubeTags
        var id: Int { hashValue }
        var title: String {
            switch self {
            case .recentSearches: return "Clear recent searches?"
            case .recentlyPlayed: return "Clear recently played?"
            case .artworkCache:   return "Clear artwork cache?"
            case .youtubeTags:    return "Forget saved YouTube tags?"
            }
        }
        var confirm: String { "Clear" }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                itemRow("magnifyingglass", "Recent searches",
                        detail: "\(recentSearchesCount) saved",
                        action: .recentSearches)
                divider
                itemRow("clock.arrow.circlepath", "Recently played",
                        detail: "\(player.recentlyPlayed.count) songs",
                        action: .recentlyPlayed)
                divider
                itemRow("photo.stack", "Artwork cache",
                        detail: cacheSummary,
                        action: .artworkCache)
                divider
                itemRow("arrow.down.circle", "Saved YouTube tags",
                        detail: "\(player.savedYouTube.count) marked saved this session",
                        action: .youtubeTags)
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
            .padding(.horizontal, 20).padding(.top, 12)

            Text("Storage settings only affect this device.")
                .retro(9, .light, color: Theme.graphite, tracking: 1.5)
                .padding(.top, 14)
        }
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { detailTitle("Storage") }
        .task { refresh() }
        .confirmationDialog(pending?.title ?? "", isPresented: Binding(
            get: { pending != nil },
            set: { if !$0 { pending = nil } }
        ), titleVisibility: .visible) {
            if let p = pending {
                Button(p.confirm, role: .destructive) { perform(p) }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    private var divider: some View { Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 54) }

    private var cacheSummary: String {
        let mb = Double(cacheBytes) / (1024 * 1024)
        return mb < 0.1 ? "empty" : String(format: "%.1f MB", mb)
    }

    private func itemRow(_ icon: String, _ title: String, detail: String, action: Action) -> some View {
        Button { pending = action } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 15)).foregroundStyle(Theme.accent).frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).retro(13, .medium)
                    Text(detail).retro(9, .light, color: Theme.graphite, tracking: 1).lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "trash").font(.footnote).foregroundStyle(Theme.graphite)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func refresh() {
        if let data = UserDefaults.standard.data(forKey: recentSearchesKey),
           let arr = try? JSONDecoder().decode([String].self, from: data) {
            recentSearchesCount = arr.count
        } else {
            recentSearchesCount = 0
        }
        cacheBytes = URLCache.shared.currentDiskUsage + URLCache.shared.currentMemoryUsage
    }

    private func perform(_ action: Action) {
        switch action {
        case .recentSearches:
            UserDefaults.standard.removeObject(forKey: recentSearchesKey)
        case .recentlyPlayed:
            player.clearRecentlyPlayed()
        case .artworkCache:
            URLCache.shared.removeAllCachedResponses()
        case .youtubeTags:
            player.clearSavedYouTube()
        }
        refresh()
    }
}

// MARK: - Help

struct HelpSettings: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                help("Play & queue", "Tap a song to play it. Long-press or use the ••• menu for Play next, Add to queue, Favourite, and Add to playlist.")
                help("The record", "The full player shows your track as a spinning record; the teal arc is the elapsed time. Drag the bar to seek.")
                help("YouTube", "Songs not in your library appear in Search with a red YouTube tag. Play them instantly, and tap the download button in the player to save a permanent copy to your library.")
                help("Favourites", "Tap the heart in the player to favourite a song; find them all under the Favourites tab.")
            }
            .padding(20).padding(.bottom, 40)
        }
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { detailTitle("Welcome Guide") }
    }

    private func help(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).retro(14, .semibold, tracking: 1)
            Text(body).font(.subheadline).foregroundStyle(Theme.graphite)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
    }
}
