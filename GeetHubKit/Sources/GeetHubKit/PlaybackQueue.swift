import Foundation

/// Pure playback-queue logic: current track, up-next, shuffle, repeat, and edits.
/// No AVFoundation here — the app wraps this in an observable object and drives
/// an AVQueuePlayer from it. Kept framework-free so it's fully unit-testable.
public struct PlaybackQueue: Sendable, Equatable {
    public enum RepeatMode: Sendable, Equatable { case off, all, one }

    /// Tracks in the order they were added.
    public private(set) var items: [Song]
    /// Play order — indices into `items` (identity when not shuffled).
    private var order: [Int]
    /// Position within `order` of the current track (nil = nothing playing).
    public private(set) var position: Int?

    public var repeatMode: RepeatMode
    public private(set) var isShuffled: Bool

    public init() {
        items = []
        order = []
        position = nil
        repeatMode = .off
        isShuffled = false
    }

    // MARK: - Read

    public var isEmpty: Bool { items.isEmpty }
    public var count: Int { items.count }

    public var current: Song? {
        guard let position, order.indices.contains(position) else { return nil }
        return items[order[position]]
    }

    public var upNext: [Song] {
        guard let position, position + 1 < order.count else { return [] }
        return order[(position + 1)...].map { items[$0] }
    }

    // MARK: - Load

    /// Replace the queue with `songs` and start at `startAt`. Honors current
    /// shuffle state (the chosen track always plays first when shuffled).
    public mutating func load(_ songs: [Song], startAt startIndex: Int = 0) {
        items = songs
        guard !songs.isEmpty else { order = []; position = nil; return }
        let start = min(max(startIndex, 0), songs.count - 1)
        if isShuffled {
            var rest = Array(0..<songs.count)
            rest.removeAll { $0 == start }
            rest.shuffle()
            order = [start] + rest
            position = 0
        } else {
            order = Array(0..<songs.count)
            position = start
        }
    }

    // MARK: - Transport

    /// Advance. `auto` = natural track end (repeat-one replays the same track);
    /// a user skip passes `auto: false`. Returns the new current (nil at the end).
    @discardableResult
    public mutating func next(auto: Bool = false) -> Song? {
        guard let pos = position else { return nil }
        if auto, repeatMode == .one { return current }
        if pos + 1 < order.count {
            position = pos + 1
        } else if repeatMode == .all {
            position = 0
        } else {
            // Reached the end with no repeat.
            if auto { position = nil }   // stop after last track finishes
            return current
        }
        return current
    }

    @discardableResult
    public mutating func previous() -> Song? {
        guard let pos = position else { return nil }
        if pos > 0 {
            position = pos - 1
        } else if repeatMode == .all {
            position = order.count - 1
        }
        return current
    }

    public mutating func jump(to orderPosition: Int) {
        guard order.indices.contains(orderPosition) else { return }
        position = orderPosition
    }

    // MARK: - Shuffle

    public mutating func setShuffled(_ on: Bool) {
        guard on != isShuffled else { return }
        let playing = current  // preserve the track under the needle
        isShuffled = on
        if on {
            if let cur = playing, let curItem = items.firstIndex(of: cur) {
                var rest = Array(0..<items.count)
                rest.removeAll { $0 == curItem }
                rest.shuffle()
                order = [curItem] + rest
                position = 0
            } else {
                order = Array(0..<items.count).shuffled()
                position = items.isEmpty ? nil : 0
            }
        } else {
            order = Array(0..<items.count)
            position = playing.flatMap { items.firstIndex(of: $0) }
        }
    }

    public mutating func toggleShuffle() { setShuffled(!isShuffled) }

    // MARK: - Edit

    public mutating func append(_ song: Song) {
        items.append(song)
        order.append(items.count - 1)
        if position == nil { position = 0 }
    }

    /// Insert a song to play right after the current track.
    public mutating func playNext(_ song: Song) {
        items.append(song)
        let newIndex = items.count - 1
        let insertAt = (position ?? -1) + 1
        order.insert(newIndex, at: min(insertAt, order.count))
        if position == nil { position = 0 }
    }

    /// Remove the track at an `order` position, keeping `current` sensible.
    public mutating func remove(atOrderPosition p: Int) {
        guard order.indices.contains(p) else { return }
        let removedItem = order[p]
        order.remove(at: p)
        items.remove(at: removedItem)
        // Any order index pointing past the removed item shifts down by one.
        order = order.map { $0 > removedItem ? $0 - 1 : $0 }

        if let pos = position {
            if order.isEmpty { position = nil }
            else if p < pos { position = pos - 1 }
            else if p == pos { position = min(pos, order.count - 1) }
        }
    }

    public mutating func clear() {
        items = []
        order = []
        position = nil
    }
}
