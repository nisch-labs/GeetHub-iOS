// App-target file. Settings — a list of categories, each opening a detail page.
import SwiftUI
import GeetHubKit

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Text("Settings").retro(30, .bold, tracking: 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 4)

                    card("cylinder.split.1x2.fill", "Server & Account",
                         "Server info, credentials, log out") { ServerAccountSettings() }
                    card("paintpalette.fill", "Appearance & Layout",
                         "Theme, accent color, sort order") { AppearanceSettings() }
                    card("music.note", "Sound & Playback",
                         "Streaming quality, player controls") {
                        PlaceholderSettings(title: "Sound & Playback", icon: "music.note",
                                            message: "Streaming and download quality options are on the way.")
                    }
                    card("globe", "Connectivity",
                         "Server URL, offline mode, certificates") {
                        PlaceholderSettings(title: "Connectivity", icon: "globe",
                                            message: "Offline mode and certificate options are coming soon.")
                    }
                    card("folder.fill", "Storage",
                         "Cache, downloads, storage limits") {
                        PlaceholderSettings(title: "Storage", icon: "folder.fill",
                                            message: "Download and cache management arrives with offline support.")
                    }
                    card("books.vertical.fill", "Library & Data",
                         "Listening history, backups, shares") {
                        PlaceholderSettings(title: "Library & Data", icon: "books.vertical.fill",
                                            message: "History, backups and sharing are planned for a later update.")
                    }
                    card("questionmark.circle.fill", "Help & Welcome Guide",
                         "Gestures, features, and tips") { HelpSettings() }

                    Text("Geet-Hub · Version 0.1")
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
            HStack(spacing: 14) {
                Image(systemName: icon).font(.title3).foregroundStyle(Theme.accent).frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).retro(15, .semibold)
                    Text(subtitle).retro(9, .light, color: Theme.graphite, tracking: 0.5).lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Theme.graphite)
            }
            .padding(16)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
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

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 0) {
                    if let host = session.client?.credentials.baseURL.host {
                        row("Server", host); divider
                    }
                    if let user = session.client?.credentials.username {
                        row("User", user); divider
                    }
                    row("Version", "0.1")
                }
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
                .padding(.horizontal, 20).padding(.top, 12)

                Button { session.signOut() } label: {
                    Text("Log out").retro(14, .semibold, color: .white, tracking: 2)
                        .frame(maxWidth: .infinity).padding(.vertical, 14).background(Theme.accent)
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 40)
        }
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { detailTitle("Server & Account") }
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
}

// MARK: - Appearance & Layout

struct AppearanceSettings: View {
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        ScrollView {
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
            .padding(.horizontal, 20).padding(.top, 12)
        }
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { detailTitle("Appearance & Layout") }
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

// MARK: - Placeholder

struct PlaceholderSettings: View {
    let title: String
    let icon: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(message)
        }
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { detailTitle(title) }
    }
}
