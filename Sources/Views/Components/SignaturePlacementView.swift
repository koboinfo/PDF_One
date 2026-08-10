import SwiftUI

/// ページサムネイルの上に署名画像をドラッグで配置するプレビュー。座標系は左上原点(pt)。
struct SignaturePlacementView: View {
    let pageThumbnail: UIImage
    let previewSize: CGSize
    let signatureImage: UIImage
    @Binding var position: CGPoint
    @Binding var size: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(uiImage: pageThumbnail)
                .resizable()
                .frame(width: previewSize.width, height: previewSize.height)

            Image(uiImage: signatureImage)
                .resizable()
                .scaledToFit()
                .frame(width: size.width, height: size.height)
                .position(x: position.x + size.width / 2, y: position.y + size.height / 2)
                .gesture(dragGesture)
        }
        .frame(width: previewSize.width, height: previewSize.height)
        .clipped()
        .border(Color.secondary.opacity(0.3))
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let clampedX = min(max(0, value.location.x - size.width / 2), previewSize.width - size.width)
                let clampedY = min(max(0, value.location.y - size.height / 2), previewSize.height - size.height)
                position = CGPoint(x: clampedX, y: clampedY)
            }
    }
}
