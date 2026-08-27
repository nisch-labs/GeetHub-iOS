# Geet-Hub — iOS / iPad / Mac Catalyst

A lightweight, streaming-first music client for your own self-hosted
[Navidrome](https://www.navidrome.org/) / Subsonic server.

_“Geet” = song._

Part of the [Geet-Hub](https://github.com/nisch-labs/GeetHub) self-hosted
music ecosystem — see the umbrella repo for the full stack (Navidrome +
[subsonic-proxy](https://github.com/nisch-labs/GeetHub-Subsonic-Proxy) +
[Antra](https://github.com/nisch-labs/GeetHub-Antra)).

## Features

- **Universal**: iPhone, iPad, and Mac Catalyst — one codebase, native on each
- **Library browse** — Songs / Albums / Artists / Playlists / Genres
- **Full player** — vinyl-record UI with tonearm progress arc, marquee title,
  shuffle / repeat / up-next queue / sleep timer, lyrics tab
- **Favourites & playlists** — server-persisted; create, add, reorder
- **Live search** — transient by design (never persists results locally,
  unlike sync-based clients)
- **YouTube / YouTube Music** results inline via subsonic-proxy — play a
  virtual track instantly, or save it into your Navidrome library
- **Downloader** — paste any Spotify / YouTube / Apple Music / Deezer /
  Tidal / etc. URL and it downloads to your library through Antra, with
  per-track progress
- **Multi-device sync** — Spotify-Connect-style: see all your signed-in
  devices (iPhone / iPad / Mac / web), transfer playback with a tap
- **Home-screen widget** (iOS 17+) with interactive play / pause / next
  via `AudioPlaybackIntent`; lock-screen artwork + media-key routing
- **Right-docked full player** on iPad + Mac Catalyst
- **Multi-server accounts** — add / switch / edit / remove Navidrome instances
- **Per-app volume slider** in the Full Player (independent of system volume)
- **Dark + light mode**

## Architecture

Geet-Hub is the **client half** of a small self-hosted stack:

```
┌─────────────────┐            ┌─────────────────┐
│   Geet-Hub      │            │   Web player    │
│   (this repo)   │            │  (Svelte SPA)   │
└────────┬────────┘            └────────┬────────┘
         │                              │
         └───────────┬──────────────────┘
                     ▼
            ┌────────────────┐
            │ subsonic-proxy │  ← FastAPI, thin layer over Navidrome
            └───┬────────┬───┘
                │        │
                ▼        ▼
        ┌───────────┐  ┌───────────┐
        │ Navidrome │  │  Antra    │  ← downloads land in /music
        │ (streams  │  │  (fetches │     Navidrome scans and serves
        │  files)   │  │  audio)   │
        └───────────┘  └───────────┘
```

The proxy handles YouTube search injection, save-to-library, Antra
pass-through, and multi-device coordination. The app just speaks Subsonic
(plus a handful of custom endpoints exposed by the proxy). No local library
mirror — search results are transient and never persisted.

## Requirements

- **macOS 15+** with **Xcode 16+** to build
- **iOS 17+** (device or simulator) — required for the widget's
  interactive `AudioPlaybackIntent`
- A running **[subsonic-proxy](https://github.com/nisch-labs/GeetHub-Subsonic-Proxy)**
  pointing at your Navidrome instance
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `.xcodeproj` is
  generated from `project.yml`

## Build & run

```sh
# One-time
brew install xcodegen

# Get the code + generate the project
git clone https://github.com/nisch-labs/GeetHub-iOS.git
cd GeetHub-iOS
xcodegen generate
open GeetHub.xcodeproj
```

### Personalise before you build

`project.yml` contains identifiers that need to be yours, not mine, before
Xcode will sign the build to your device:

| Field | Change to |
|---|---|
| `DEVELOPMENT_TEAM: J27CK6TLVS` (both targets) | Your own Apple Team ID (Apple Developer Portal → Membership) |
| `PRODUCT_BUNDLE_IDENTIFIER: com.nixsocket.geethub` | Something under your reversed-domain, e.g. `com.yourdomain.geethub` |
| `PRODUCT_BUNDLE_IDENTIFIER: com.nixsocket.geethub.widget` | Matching widget bundle, e.g. `com.yourdomain.geethub.widget` |
| App Group `group.com.nixsocket.geethub` (in `App/GeetHub.entitlements` and `Widget/GeetHubWidget.entitlements`) | `group.com.yourdomain.geethub` — must match on both files, and be added to your Apple Developer account under Certificates → Identifiers → App Groups |

Then re-run `xcodegen generate` to regenerate `.xcodeproj` and open it in
Xcode. Automatic signing should pick up your team.

### First run

Launch the app → **Add Server** → enter your subsonic-proxy URL, username,
password. That's it — no local config files.

## Repository layout

```
GeetHub-iOS/
├── App/                  SwiftUI app target (iPhone / iPad / Mac Catalyst)
│   ├── GeetHubApp.swift  @main
│   ├── MainTabView.swift Tab shell + right-dock layout
│   ├── NowPlaying.swift  Mini bar + full vinyl player
│   ├── PlayerEngine.swift AVPlayer wrapper, multi-device, volume, widget bridge
│   ├── DevicesSheet.swift Multi-device transfer sheet
│   ├── AntraView.swift   Downloader UI
│   └── ...
├── Widget/               Home-screen widget extension (WidgetKit + AppIntents)
├── GeetHubKit/           Portable Swift Package
│   └── Sources/GeetHubKit/
│       ├── SubsonicClient.swift  Async Subsonic API client
│       ├── SubsonicModels.swift  Codable entities (incl. custom types)
│       ├── SubsonicCredentials.swift  salted-MD5 auth
│       ├── PlaybackQueue.swift   shuffle / repeat / up-next
│       ├── Session.swift         login flow
│       └── ...
├── project.yml           XcodeGen source of truth
└── PROJECT.md            Original design notes (historical context)
```

## Contributing

Issues and PRs welcome. If you're planning something bigger than a bug fix,
please open an issue first so we can talk through the approach.

## License

MIT — see [LICENSE](LICENSE).

## Related repos

- **[GeetHub](https://github.com/nisch-labs/GeetHub)** — umbrella: architecture,
  screenshots, `docker-compose.yml` for the full stack
- **[GeetHub-Subsonic-Proxy](https://github.com/nisch-labs/GeetHub-Subsonic-Proxy)** —
  FastAPI backend + Svelte web player
- **[GeetHub-Antra](https://github.com/nisch-labs/GeetHub-Antra)** — Antra
  fork for URL-based downloads (Elastic License 2.0)
- **[Navidrome](https://www.navidrome.org/)** — the underlying music server
  (third-party, MIT)
