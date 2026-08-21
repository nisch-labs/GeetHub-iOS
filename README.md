# Geet-Hub 🎵

A **lightweight, streaming-first iOS music client** for a self-hosted
[Navidrome](https://www.navidrome.org/) / Subsonic server, with **CarPlay**.

_“Geet” = song._ Built as a minimal alternative to heavier sync-based clients
(like Amperfy) — no local library mirror, so **searching never persists anything**.
Anything you keep is an explicit action.

## Why it exists

It's the client half of a setup where a server-side proxy (`subsonic-proxy`)
augments Navidrome: searching also returns **YouTube** results you can play
instantly, and adding a track to a special **“Download via Antra”** playlist
pulls a permanent copy into the library. Because all that logic lives in the
proxy, the client stays thin — it just speaks the Subsonic API. Heavier clients
that mirror the whole library into a local database re-persist every search
result they display; Geet-Hub deliberately does not.

## Status

**Early scaffold.** The portable core is built and tested; the app + CarPlay
targets are created in Xcode (see `PROJECT.md`).

- ✅ `GeetHubKit` — Swift Package: Subsonic API client + models + salted-MD5
  token auth. Compiles and unit-tested (`swift test`).
- ⬜ App target (SwiftUI) — browse / search / play / queue / now-playing.
- ⬜ CarPlay scene + templates.
- ⬜ Playlist editing UI.

## Layout

```
Geet-Hub/
├─ PROJECT.md            full build spec / handoff notes (read this first)
├─ GeetHubKit/           Swift Package — portable, no UIKit, no persistence
│  ├─ Package.swift
│  ├─ Sources/GeetHubKit/
│  │  ├─ SubsonicCredentials.swift   auth (u/t/s salted MD5)
│  │  ├─ SubsonicModels.swift        Codable entities
│  │  └─ SubsonicClient.swift        async API (search is transient by design)
│  └─ Tests/GeetHubKitTests/
└─ (app + CarPlay targets — added in Xcode on the build machine)
```

## Build the core

```sh
cd GeetHubKit
swift build
swift test
```

## The app / CarPlay target

Created in Xcode (iOS 17+), depending on `GeetHubKit`. Needs Apple's
`carplay-audio` entitlement (paid account + approval). CarPlay templates and
Subsonic request/response shapes can be referenced from
[Amperfy](https://github.com/BLeeEZ/Amperfy) (GPL-3.0). See `PROJECT.md`.

## License

**GPL-3.0** — required because the app target reuses code from Amperfy (GPL-3.0).
Add the full license text (`LICENSE`) when publishing the GitHub repo.
