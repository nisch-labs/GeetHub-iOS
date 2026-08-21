// App-target file. Async cover art. Two shapes: `.sleeve` (sharp square — the
// album sleeve in grids) and `.record` (circle — the vinyl on the platter).
import SwiftUI
import GeetHubKit

enum ArtShape { case sleeve, record }

struct ArtworkImage: View {
    @Environment(Session.self) private var session
    let coverArt: String?
    var size: CGFloat = 56
    var shape: ArtShape = .sleeve
    var corner: CGFloat = 12

    var body: some View {
        let framed = content.frame(width: size, height: size)
        switch shape {
        case .sleeve:
            let r = RoundedRectangle(cornerRadius: corner, style: .continuous)
            framed.clipShape(r).overlay(r.strokeBorder(Theme.hairline, lineWidth: 1))
        case .record:
            framed
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
        }
    }

    @ViewBuilder private var content: some View {
        if let url = artworkURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                default: placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var artworkURL: URL? {
        guard let coverArt, let client = session.client else { return nil }
        return client.coverArtURL(id: coverArt, size: Int(size * 3))
    }

    private var placeholder: some View {
        Theme.surface.overlay(
            Image(systemName: "opticaldisc")
                .font(.system(size: size * 0.35))
                .foregroundStyle(Theme.graphite)
        )
    }
}
