// App-target file. Devices sheet — Spotify-style device switcher accessible
// from the full player. Shows all of the user's currently-registered devices;
// tap one to transfer playback.
import SwiftUI
import GeetHubKit

struct DevicesSheet: View {
    @Environment(PlayerEngine.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if player.devices.isEmpty {
                        empty.padding(.top, 60)
                    } else {
                        ForEach(player.devices) { d in
                            row(d)
                            Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 60)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .paperBackground()
            .refreshable { await player.refreshDevices() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Devices").retro(12, .semibold, tracking: 2)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.down") }
                }
            }
        }
        .task { await player.refreshDevices() }
    }

    // MARK: - Row

    @ViewBuilder private func row(_ device: Device) -> some View {
        let isSelf = device.id == player.deviceId
        Button {
            guard !isSelf else { return }
            Task { await player.transferPlayback(to: device.id) }
            dismiss()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: iconFor(kind: device.kind))
                    .font(.title2)
                    .foregroundStyle(device.isPlaying ? Theme.accent : Theme.ink)
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(device.name).retro(13, .semibold).lineLimit(1)
                        if isSelf {
                            Text("This device")
                                .retro(9, .light, color: Theme.graphite, tracking: 1)
                        }
                    }
                    Text(subtitleFor(device))
                        .retro(9, .light, color: Theme.graphite, tracking: 1)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if device.isPlaying {
                    Image(systemName: "waveform")
                        .font(.footnote).foregroundStyle(Theme.accent)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
            .contentShape(Rectangle())
            .opacity(isSelf ? 0.7 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isSelf)
    }

    private func iconFor(kind: String) -> String {
        switch kind {
        case "iphone": return "iphone"
        case "ipad":   return "ipad"
        case "mac":    return "laptopcomputer"
        case "web":    return "safari"
        default:       return "speaker.wave.2"
        }
    }

    private func subtitleFor(_ d: Device) -> String {
        if let song = d.currentSong {
            let who = song.artist.map { "\($0) — " } ?? ""
            return d.isPlaying ? "Playing · \(who)\(song.title)" : "Paused · \(who)\(song.title)"
        }
        return d.isPlaying ? "Playing" : "Idle"
    }

    // MARK: - Empty

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "speaker.wave.2")
                .font(.system(size: 34)).foregroundStyle(Theme.graphite)
            Text("No other devices").retro(13, .semibold)
            Text("Sign in on another device to see it here.")
                .retro(9, .light, color: Theme.graphite, tracking: 1)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
