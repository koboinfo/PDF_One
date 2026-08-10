import SwiftUI

struct PageThumbnailCell: View {
    let item: PDFPageEditItem
    let displayIndex: Int
    let onRotate: () -> Void
    let onDelete: () -> Void
    let onToggleSelect: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                thumbnailImage
                    .resizable()
                    .scaledToFit()
                    .rotationEffect(.degrees(Double(item.rotation)))
                    .frame(width: 100, height: 140)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(item.isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                    )
                    .onTapGesture(perform: onToggleSelect)

                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .red)
                        .background(Circle().fill(.white))
                }
                .offset(x: 8, y: -8)
            }

            HStack {
                Text("\(displayIndex)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: onRotate) {
                    Image(systemName: "rotate.right")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .frame(width: 100)
    }

    private var thumbnailImage: Image {
        if let thumbnail = item.thumbnail {
            return Image(uiImage: thumbnail)
        }
        return Image(systemName: "doc.text")
    }
}
