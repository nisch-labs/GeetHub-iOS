// App-target file. Text that gently scrolls left↔right when it's too wide to fit.
import SwiftUI

private struct TextWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct MarqueeText: View {
    let text: String
    var size: CGFloat = 24
    var weight: Font.Weight = .semibold
    var tracking: CGFloat = 1
    var color: Color = Theme.ink

    @State private var textWidth: CGFloat = 0
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            let overflow = max(0, textWidth - geo.size.width)
            styled
                .fixedSize()
                .background(GeometryReader { t in
                    Color.clear.preference(key: TextWidthKey.self, value: t.size.width)
                })
                .offset(x: (overflow > 0 && animate) ? -overflow : 0)
                .frame(width: geo.size.width, alignment: .leading)
                .clipped()
                .onPreferenceChange(TextWidthKey.self) { textWidth = $0 }
                .animation(
                    overflow > 0
                        ? .linear(duration: max(3, Double(overflow) / 22)).delay(1).repeatForever(autoreverses: true)
                        : .default,
                    value: animate
                )
                .onAppear { animate = true }
        }
        .frame(height: size * 1.28)
    }

    private var styled: some View {
        Text(text.uppercased())
            .font(.oswald(size, weight))
            .tracking(tracking)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}
