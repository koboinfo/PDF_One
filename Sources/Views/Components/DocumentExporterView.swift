import SwiftUI
import UniformTypeIdentifiers

/// 生成物をFilesアプリ等へ「保存」するためのエクスポート用ドキュメントピッカー。共有シートとは別に「保存」操作を提供する。
struct DocumentExporterView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        UIDocumentPickerViewController(forExporting: [url], asCopy: true)
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}
