// App-target file. Local, persisted "favourite playlists" (Subsonic has no
// server-side concept of starring a playlist, so we keep it on-device).
import SwiftUI

@MainActor
@Observable
final class PlaylistFavorites {
    private(set) var ids: Set<String> = []
    private let key = "favoritePlaylists"

    init() {
        if let stored = UserDefaults.standard.array(forKey: key) as? [String] {
            ids = Set(stored)
        }
    }

    func isFavorite(_ id: String) -> Bool { ids.contains(id) }

    func toggle(_ id: String) {
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        UserDefaults.standard.set(Array(ids), forKey: key)
    }
}
