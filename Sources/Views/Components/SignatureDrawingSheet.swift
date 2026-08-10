import PencilKit
import SwiftUI

/// PencilKitキャンバスでサインを描画し、線の境界でトリミングしたUIImageを返すシート。
struct SignatureDrawingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var canvasView = PKCanvasView()
    let onComplete: (UIImage) -> Void

    var body: some View {
        NavigationStack {
            SignatureCanvasView(canvasView: $canvasView)
                .background(Color(white: 0.95))
                .navigationTitle("署名を描く")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("クリア") { canvasView.drawing = PKDrawing() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完了") { completeDrawing() }
                            .disabled(canvasView.drawing.bounds.isEmpty)
                    }
                }
        }
    }

    private func completeDrawing() {
        let bounds = canvasView.drawing.bounds
        guard !bounds.isEmpty else { return }
        let image = canvasView.drawing.image(from: bounds, scale: UIScreen.main.scale)
        onComplete(image)
        dismiss()
    }
}
