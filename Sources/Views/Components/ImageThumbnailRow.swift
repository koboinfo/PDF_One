import SwiftUI

struct ImageThumbnailRow: View {
    let image: AppImage

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(image.displayURL.lastPathComponent)
                    .lineLimit(1)

                if image.isRemote {
                    Text(String(localized: "リモート"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        switch image.source {
        case .local(let url):
            localThumbnailImage(at: url)
                .resizable()
                .scaledToFill()
        case .remote(let url):
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let loadedImage):
                    loadedImage
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholder
                case .empty:
                    ProgressView()
                @unknown default:
                    placeholder
                }
            }
        }
    }

    private var placeholder: some View {
        Image(systemName: "photo")
            .foregroundStyle(.secondary)
    }

    private func localThumbnailImage(at url: URL) -> Image {
        if let data = try? Data(contentsOf: url), let uiImage = UIImage(data: data) {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "photo")
    }
}
