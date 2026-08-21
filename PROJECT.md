# Custom Lightweight iOS Subsonic Client — Project Notes

Status: **scaffolding** · Started Aug 21 2026 · Owner: Nischal · Repo: `Geet-Hub/`

**Scaffold done (Aug 21 2026):** `GeetHubKit/` Swift Package builds + passes
`swift test` — Subsonic API client (`SubsonicClient`), Codable models, and
salted-MD5 token auth (`SubsonicCredentials`). Search is transient by design (no
persistence). Next: create the SwiftUI app + CarPlay targets in Xcode on the
build laptop, depending on GeetHubKit. This whole folder migrates to the other
laptop.

A from-consideration record for building our own minimal iOS music client for the
Navidrome/Subsonic setup, to replace Amperfy. Living doc — update as decisions land.

---

## Why we're building this

The `subsonic-proxy` (see `CLAUDE.md` → Installed apps, and workspace
`subsonic-proxy/`) already gives any Subsonic client YouTube search + instant play
+ hybrid Deezer→Antra/YouTube download. The remaining problem is the **client**:

- **Amperfy is a full-library-sync client.** Its Search persists every `search3`
  result into a local Core Data DB and renders from that DB. So every YouTube
  search result we inject gets **permanently saved** into Amperfy's local library
  (cosmetic clutter in the Songs list; clears only on re-sync). Confirmed by
  reading Amperfy source — displaying a search result and saving it are the same
  operation; there is no transient-search path.
- Nischal's requirement: **only songs explicitly added to the "Download via
  Antra" playlist should end up anywhere; nothing from search should randomly
  persist.** Amperfy architecturally can't do this.
- Streaming-first off-the-shelf clients (Substreamer, NaviBeat, play:Sub) solve
  the persistence problem AND have CarPlay, but Nischal wants a client tuned
  exactly to his use case: **very lightweight, fast, CarPlay, proper streaming,
  no fancy stuff** — and is willing to maintain it and open-source it.

Key architectural win: **all custom logic lives in the proxy, not the client.**
So the client stays thin — a Subsonic browser + player + CarPlay. The proxy makes
YouTube results appear in search, stream on play, and trigger downloads on
playlist-add. The client needs no special code for any of that.

---

## Client search-behavior finding (proven Aug 21 2026, from proxy request logs)

The whole YouTube-in-search feature depends on the client sending the **typed
query to the server live** (`search3?query=<text>`). Two camps, confirmed by
watching real requests hit the proxy:

| Client | Sends typed query to server? | Persists results? | YouTube feature |
|---|---|---|---|
| **Amperfy** | YES — live `search3?query=…&songCount=40` | YES (writes to local Core Data → clutter) | **Works** — fork must make it transient |
| **Substreamer** | NO — full-syncs the library (`query=&songCount=5000` paging) then searches its LOCAL cache; a typed "Mykonos" produced **0** server queries | (syncs whole library) | **Impossible** — proxy never sees the query |

Conclusion: **forking Amperfy is the only base where the feature can work**,
because it's the one client that actually queries the server for typed searches.
Substreamer/other full-sync-local-search clients can't surface injected results
no matter what the proxy does. (This also corrects an earlier optimistic
inference that Substreamer was "live/transient" — in practice it is not.)

## Hard constraints / gotchas

- **CarPlay entitlement (the real gate).** CarPlay audio apps require Apple's
  `com.apple.developer.carplay-audio` entitlement. Per Apple docs you **cannot
  produce a signed, installable CarPlay build — even for personal sideload —
  until Apple assigns the entitlement to your account.** Requires a **paid Apple
  Developer account** (Nischal HAS one) + a **case-by-case Apple approval**
  (app type "Audio"; days-to-weeks, no SLA).
  - Request form: https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements
  - **Action: submit the request ASAP** so approval is in flight while we build.
  - Development + **CarPlay Simulator** testing work immediately with the paid
    account; the entitlement only gates installing on a real car/head unit.
- Signing/distribution: paid account → 1-year signing, TestFlight (90-day
  builds). Fine given maintenance commitment.
- Streaming: proxy returns YouTube tracks as a **live chunked mp3 transcode with
  no fixed Content-Length and no byte-range/seek**. Player must tolerate
  progressive/chunked streams (AVPlayer does; seeking within a transcoded
  stream may be limited — inherent, not app-specific).

## Claude's role vs Nischal's

- Claude writes all Swift, structures the project, iterates on code.
- Claude **cannot** run Xcode builds or sign to a device from here. Nischal
  drives Xcode (project creation, signing/team/bundle id/entitlements via the
  Xcode UI, running on simulator/device) and pastes back build errors. Option:
  set up `xcodebuild` CLI so Claude can compile-check.

---

## Proposed architecture (v1)

- **From-scratch SwiftUI**, iOS 17+. No local library mirror → live browse/search
  → nothing persists from searching (solves the core requirement).
- **AVQueuePlayer** for streaming + queue; `MPNowPlayingInfoCenter` + remote
  command center for lock screen / CarPlay transport.
- **CarPlay** via `CPTemplateApplicationScene` (library / playlists /
  now-playing templates).
- **Thin Subsonic client** — only the endpoints we use:
  `ping`, `getArtists`, `getAlbumList2`, `getAlbum`, `search3`,
  `getPlaylists`, `getPlaylist`, `updatePlaylist`, `stream`, `getCoverArt`,
  `scrobble`. Auth via token+salt (`t`/`s`) like Amperfy does.
- Server target: the proxy — `http://100.75.88.86:4544` (Tailscale). Falls back
  to `:4533` (direct Navidrome) if proxy is bypassed.
- Custom features come free from the proxy: YouTube results in search, play,
  and add-to-"Download via Antra" → hybrid download.

Rough size: ~15–20 Swift files. Milestone path: play music in the simulator
early → add CarPlay → polish.

---

## Decisions (locked Aug 21 2026)

1. **Base: FROM SCRATCH (minimal SwiftUI), with Amperfy as a reference — NOT a
   fork.** Revised from an initial "fork Amperfy" after pulling hard numbers on
   both repos (see Repo comparison below). Rationale:
   - Amperfy is native Swift and forkable BUT **heavy**: ~92k LOC, 440 Swift
     files, a Core Data library-mirror model migrated **v2→v28**, plus a full
     offline-cache engine. Its Core Data mirror is the very thing that causes the
     search-persistence problem — forking means gutting the architectural core.
   - Substreamer is **disqualified twice over**: it's a **React Native/Expo
     (TypeScript)** app, not native Swift (forking = adopting the whole RN/Expo
     toolchain, the opposite of lightweight), AND it does local-only search.
   - From scratch, "**nothing persists from search**" is automatic — no local
     library mirror; pass the typed query straight to the server and render
     results in memory. This is the core requirement, for free.
   - **Reuse Amperfy's two hard parts by copying (GPLv3 → derivative stays
     GPLv3):** its **CarPlay templates** (`Amperfy/CarPlay/*`, 7 files) and its
     **Subsonic API request/response handling** (`AmperfyKit/Api`). Skip the
     fiddly bits without inheriting the 92k-LOC engine.
2. **v1 scope: browse + search + play, CarPlay, playlist editing.** Offline
   downloads deferred to v2.
3. **Name & repo location** — TBD.
4. **Build workflow** — TBD: Xcode-only (Nischal builds, pastes errors) vs also
   wire `xcodebuild` for Claude compile-checks.
5. Keep the proxy as-is (client-agnostic) — **yes**.

## Repo comparison (hard numbers, Aug 21 2026)

| | **Amperfy** `BLeeEZ/Amperfy` | **Substreamer** `ghenry22/substreamer` |
|---|---|---|
| Forkable as native iOS? | **Yes** (native Swift) | **No** — React Native/Expo (TypeScript) |
| License | GPL-3.0 | GPL-3.0 |
| Size | **~92k LOC, 440 Swift files**, ~30 MB repo | RN/JS tree, ~66 MB repo |
| Architecture | **Core Data mirror (model v2→v28)** + offline-cache engine + `AmperfyKit` framework; UIKit shell + SwiftUI screens | Expo + Drizzle SQLite (also local-sync) |
| Dependencies | 13 SPM (Alamofire, AudioStreaming, SnapKit, …) | large npm/Expo tree |
| CarPlay in code | **Yes — 7 files** `Amperfy/CarPlay/*` | No (RN) |
| Live server search | **Yes** (required by our setup) | No — local-only |
| Min iOS | 15.0 | Expo-managed |
| Maintenance | very active (v2.1.1, Aug 2026; 1.7k★) | active (open-sourced Feb 2026; ~292★) |

Takeaway: only Amperfy is a viable native fork, but it's a big Core Data sync
app — heavier than building minimal from scratch. Hence: **from scratch, Amperfy
as reference.**

## Getting started on the OTHER laptop (checklist)

Prereqs: macOS + Xcode (latest) + command-line tools; paid Apple Developer
account (Nischal has one); the CarPlay entitlement request submitted (see above).
Clone Amperfy locally too — as a **read-only reference** for CarPlay + Subsonic
API code (`git clone https://github.com/BLeeEZ/Amperfy`).

1. **New Xcode project** — App, SwiftUI, iOS 17+ (15+ if you want wider reach).
   Set your **Team**, bundle id (e.g. `com.nixsocket.<app>`), managed signing.
   License the repo **GPL-3.0** (required because you copy Amperfy code).
2. **Subsonic client layer** (`URLSession`, no Alamofire needed). Auth = `u` +
   token `t` + salt `s` (`t = md5(password + salt)`). Implement only:
   `ping`, `getArtists`, `getAlbumList2`, `getAlbum`, `search3`, `getPlaylists`,
   `getPlaylist`, `updatePlaylist`, `stream`, `getCoverArt`, `scrobble`.
   Reference Amperfy's `AmperfyKit/Api/Subsonic/*` for request/response shapes.
3. **Search = transient by design.** `search3?query=<text>&songCount=40…` →
   decode into an **in-memory** results model → render directly. Do NOT store to
   any local DB. (This is the whole reason for from-scratch: no Core Data mirror,
   so nothing persists.)
4. **Playback** — `AVQueuePlayer` streaming `stream?id=…`; wire
   `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter` (lock screen / CarPlay
   transport). Streams may be chunked/length-unknown (yt- tracks) — AVPlayer
   handles progressive; seek may be limited on those.
5. **CarPlay** — add `CPTemplateApplicationScene` + templates. Copy/adapt
   Amperfy's `Amperfy/CarPlay/*` (7 files: SceneDelegate + Home/Library/
   NowPlaying/List). Add the `carplay-audio` capability once Apple approves it
   (simulator works before approval).
6. **Playlist editing** — add-song-to-playlist via `updatePlaylist?...&
   songIdToAdd=…`. Adding a `yt-` track to the **"Download via Antra"** playlist
   triggers the proxy's hybrid download automatically (no special client code).
7. **Point default server at the proxy** `http://100.75.88.86:4544` (or LAN /
   Cloudflare route — see Networking note).

## Proxy integration reference (what the client talks to)

- **Base URL:** `http://100.75.88.86:4544` (proxy; Tailscale). Same Subsonic API
  as Navidrome — auth via `u` + token `t` + salt `s` (Amperfy already does this).
- **Search:** send `search3?query=<text>&songCount=40…` → proxy returns real
  library hits PLUS YouTube virtual songs (`id="yt-<videoId>"`, `album="YouTube"`,
  with `size`, `albumId`, `artist`, `duration`, `suffix=mp3`).
- **Play:** `stream?id=yt-<videoId>` → proxy resolves via yt-dlp + transcodes to
  a live **chunked mp3, no Content-Length, no seek**. Player must handle
  progressive streams (AVPlayer OK).
- **Cover art:** `getCoverArt?id=yt-<videoId>` → 302 redirect to YouTube thumb.
- **Download trigger:** add a `yt-` track to the Navidrome playlist named
  **"Download via Antra"** (`updatePlaylist?...&songIdToAdd=yt-<videoId>`) → proxy
  fires the hybrid download (Deezer→Antra flac, else save YouTube audio) and
  strips the yt id before forwarding. No special client code needed.

## Networking note (phone reachability)

- Server addresses: Tailscale `100.75.88.86` (permanent), LAN `192.168.1.88`
  (DHCP, changes), plus the ZimaOS-app VPN. **The phone can't use Tailscale**
  (one VPN per phone; it runs the ZimaOS app VPN) — so `100.75.88.86` may time
  out from the phone. Options for phone access to the proxy: same-LAN IP
  `192.168.1.88:4544`, or add a Cloudflare Tunnel route (e.g.
  `sub.nixsocket.com` → `http://127.0.0.1:4544`) like the existing
  `music.nixsocket.com` → Navidrome (mind the 100MB/request free-tier cap on
  long transcodes). Substreamer login worked once the phone had a reachable
  address.

## Open items

- App **name** (TBD) and repo location (TBD — likely your GitHub fork).
- Build workflow: Xcode-only vs also wire `xcodebuild` for compile-checks.
- Decide whether to keep Amperfy's offline-download feature (v2) or strip it.

## Related

- Proxy service: workspace `subsonic-proxy/` and `CLAUDE.md`.
- Memory: `subsonic-proxy.md` (Amperfy quirk, Antra behavior, yt-dlp nightly).
