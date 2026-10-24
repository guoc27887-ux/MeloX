import SwiftUI

struct DesktopArtworkView: View {
    let url: URL?
    var cornerRadius: CGFloat = 10
    var contentMode: ContentMode = .fill

    var body: some View {
        GeometryReader { proxy in
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    placeholder(systemImage: "music.note")
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                case .failure:
                    Image("MeloXLogo")
                        .resizable()
                        .scaledToFit()
                        .padding(18)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.quaternary.opacity(0.35))
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
    }

    private func placeholder(systemImage: String) -> some View {
        ZStack {
            Color.secondary.opacity(0.10)

            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DesktopCircularArtworkView: View {
    let url: URL?

    var body: some View {
        DesktopArtworkView(url: url, cornerRadius: 10_000)
            .clipShape(.circle)
    }
}
