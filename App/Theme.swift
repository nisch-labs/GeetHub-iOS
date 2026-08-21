// App-target file. The Geet-Hub visual system: classic / retro / vinyl / minimal.
// One teal accent, paper background, Oswald in liner-note uppercase.
import SwiftUI

enum Theme {
    static let paper    = Color(red: 0.957, green: 0.957, blue: 0.949) // #F4F4F2
    static let surface  = Color.white
    static let ink      = Color(red: 0.078, green: 0.086, blue: 0.102) // #14161A
    static let graphite = Color(red: 0.541, green: 0.561, blue: 0.596) // #8A8F98
    static let teal      = Color(red: 0.071, green: 0.475, blue: 0.561) // #12798F
    static let hairline = Color(red: 0.894, green: 0.894, blue: 0.878) // #E4E4E0
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
