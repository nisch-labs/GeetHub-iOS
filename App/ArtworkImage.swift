// App-target file. Async cover-art loader from the Subsonic getCoverArt endpoint.
import SwiftUI
import GeetHubKit

struct ArtworkImage: View {
    @Environment(Session.self) private var session
    let coverArt: String?
    var size: CGFloat = 56

    var body: some View {
        Group {
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
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size < 80 ? 6 : 10, style: .continuous))
    }

    private var artworkURL: URL? {
        guard let coverArt, let client = session.client else { return nil }
        return client.coverArtURL(id: coverArt, size: Int(size * 3))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: size < 80 ? 6 : 10, style: .continuous)
            .fill(.quaternary)
            .overlay(Image(systemName: "music.note").foregroundStyle(.secondary).font(.system(size: size * 0.4)))
    }
}
