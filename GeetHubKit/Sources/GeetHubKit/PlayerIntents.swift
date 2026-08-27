import AppIntents

/// Playback intents used by the Home-screen widget's interactive buttons.
///
/// `AudioPlaybackIntent` tells iOS this is a media-control action — the
/// system will launch the app in the background (if needed) so the perform
/// closure executes in the app's process. We just push the command onto the
/// shared queue; PlayerEngine's poll timer picks it up and executes it on
/// the main actor.
///
/// This works on iOS 17+. WidgetKit's `Button(intent:)` requires iOS 17.

@available(iOS 17.0, *)
public struct TogglePlayPauseIntent: AudioPlaybackIntent {
    public static let title: LocalizedStringResource = "Toggle Play/Pause"
    public init() {}
    public func perform() async throws -> some IntentResult {
        PlayerCommandStore.push(.togglePlayPause)
        return .result()
    }
}

@available(iOS 17.0, *)
public struct NextTrackIntent: AudioPlaybackIntent {
    public static let title: LocalizedStringResource = "Next Track"
    public init() {}
    public func perform() async throws -> some IntentResult {
        PlayerCommandStore.push(.next)
        return .result()
    }
}

@available(iOS 17.0, *)
public struct PreviousTrackIntent: AudioPlaybackIntent {
    public static let title: LocalizedStringResource = "Previous Track"
    public init() {}
    public func perform() async throws -> some IntentResult {
        PlayerCommandStore.push(.previous)
        return .result()
    }
}
