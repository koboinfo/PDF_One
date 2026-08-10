import PencilKit
import SwiftUI

struct SignatureCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 4)
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
