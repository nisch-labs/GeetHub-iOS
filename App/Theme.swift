// App-target file. The Geet-Hub visual system: classic / retro / vinyl / minimal.
// One teal accent, paper background, Oswald in liner-note uppercase.
import SwiftUI
import UIKit

enum Theme {
    // #F4F4F2 / #0E0F12
    static let paper    = dynamic(light: (0.957, 0.957, 0.949), dark: (0.055, 0.059, 0.071))
    // #FFFFFF / #1B1D22
    static let surface  = dynamic(light: (1.000, 1.000, 1.000), dark: (0.106, 0.114, 0.133))
    // #14161A / #EDEEF2
    static let ink      = dynamic(light: (0.078, 0.086, 0.102), dark: (0.929, 0.933, 0.949))
    static let graphite = Color(red: 0.541, green: 0.561, blue: 0.596) // #8A8F98 — same in both
    // #E4E4E0 / #2A2C31
    static let hairline = dynamic(light: (0.894, 0.894, 0.878), dark: (0.165, 0.173, 0.192))

    static let accentKey = "accentChoice"
    static let colorSchemeKey = "colorSchemeChoice"
    /// The current accent — user-selectable in Settings, persisted.
    static var accent: Color { AccentChoice.current.color }

    private static func dynamic(light: (CGFloat, CGFloat, CGFloat),
                                dark: (CGFloat, CGFloat, CGFloat)) -> Color {
        let l = UIColor(red: light.0, green: light.1, blue: light.2, alpha: 1)
        let d = UIColor(red: dark.0,  green: dark.1,  blue: dark.2,  alpha: 1)
        return Color(UIColor { $0.userInterfaceStyle == .dark ? d : l })
    }
}

/// Light / Dark / System — user-selectable in Settings, persisted.
enum ColorSchemeChoice: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    static var current: ColorSchemeChoice {
        ColorSchemeChoice(rawValue: UserDefaults.standard.string(forKey: Theme.colorSchemeKey) ?? "") ?? .system
    }
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
    var scheme: ColorSchemeChoice {
        didSet { UserDefaults.standard.set(scheme.rawValue, forKey: Theme.colorSchemeKey) }
    }
    init() {
        var initialAccent = AccentChoice.current
        #if DEBUG
        if let a = ProcessInfo.processInfo.environment["GEETHUB_ACCENT"], let c = AccentChoice(rawValue: a) {
            UserDefaults.standard.set(a, forKey: Theme.accentKey)   // keep static Theme.accent in sync
            initialAccent = c
        }
        #endif
        choice = initialAccent
        scheme = ColorSchemeChoice.current
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
