// App-target file. The Geet-Hub visual system: classic / retro / vinyl / minimal.
// One teal accent, paper background, Oswald in liner-note uppercase.
import SwiftUI

enum Theme {
    static let paper    = Color(red: 0.957, green: 0.957, blue: 0.949) // #F4F4F2
    static let surface  = Color.white
    static let ink      = Color(red: 0.078, green: 0.086, blue: 0.102) // #14161A
    static let graphite = Color(red: 0.541, green: 0.561, blue: 0.596) // #8A8F98
    static let hairline = Color(red: 0.894, green: 0.894, blue: 0.878) // #E4E4E0

    static let accentKey = "accentChoice"
    /// The current accent — user-selectable in Settings, persisted.
    static var accent: Color { AccentChoice.current.color }
}

/// Selectable accent colors.
enum AccentChoice: String, CaseIterable, Identifiable {
    case teal, indigo, crimson, amber, violet, forest, slate

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .teal:    return Color(red: 0.071, green: 0.475, blue: 0.561)
        case .indigo:  return Color(red: 0.263, green: 0.306, blue: 0.718)
        case .crimson: return Color(red: 0.784, green: 0.157, blue: 0.290)
        case .amber:   return Color(red: 0.831, green: 0.522, blue: 0.106)
        case .violet:  return Color(red: 0.514, green: 0.278, blue: 0.663)
        case .forest:  return Color(red: 0.129, green: 0.475, blue: 0.341)
        case .slate:   return Color(red: 0.278, green: 0.333, blue: 0.404)
        }
    }

    static var current: AccentChoice {
        AccentChoice(rawValue: UserDefaults.standard.string(forKey: Theme.accentKey) ?? "") ?? .teal
    }
}

/// Observable holder so accent changes re-tint the app live (music keeps playing).
@MainActor
@Observable
final class ThemeManager {
    var choice: AccentChoice {
        didSet { UserDefaults.standard.set(choice.rawValue, forKey: Theme.accentKey) }
    }
    init() {
        #if DEBUG
        if let a = ProcessInfo.processInfo.environment["GEETHUB_ACCENT"], let c = AccentChoice(rawValue: a) {
            UserDefaults.standard.set(a, forKey: Theme.accentKey)   // keep static Theme.accent in sync
            choice = c
            return
        }
        #endif
        choice = AccentChoice.current
    }
    var accent: Color { choice.color }
}

extension Font {
    /// Oswald — condensed display face, bundled. Falls back to system if missing.
    static func oswald(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .custom("Oswald", size: size).weight(weight)
    }
}

/// Uppercase, letter-spaced liner-note label.
private struct RetroText: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    let color: Color
    let tracking: CGFloat
    func body(content: Content) -> some View {
        content
            .font(.oswald(size, weight))
            .textCase(.uppercase)
            .tracking(tracking)
            .foregroundStyle(color)
    }
}

extension View {
    func retro(_ size: CGFloat,
               _ weight: Font.Weight = .medium,
               color: Color = Theme.ink,
               tracking: CGFloat = 1.5) -> some View {
        modifier(RetroText(size: size, weight: weight, color: color, tracking: tracking))
    }

    /// Paper background that ignores safe area.
    func paperBackground() -> some View {
        background(Theme.paper.ignoresSafeArea())
    }
}
