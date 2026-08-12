import Foundation

@Observable
@MainActor
final class MergeViewModel {

    var selectedURLs: [URL] = []
    var isProcessing: Bool = false
    var outputURL: URL?
    var errorMessage: String?

    private let pdfService: PDFServiceProtocol

    init(pdfService: PDFServiceProtocol = PDFService()) {
        self.pdfService = pdfService
    }

    func mergePDFs() async {
        guard !selectedURLs.isEmpty else {
            errorMessage = String(localized: "結合するPDFファイルを選択してください。")
            return
        }

        isProcessing = true
        errorMessage = nil
        let previousOutputURL = outputURL
        outputURL = nil
        AdMobInterstitialManager.shared.preloadAd()

        do {
            let destinationURL = try SavedFileStore.directory()
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("pdf")

            let mergedURL = try await pdfService.mergePDFs(
                inputURLs: selectedURLs,
                outputURL: destinationURL
            )
            if let previousOutputURL {
                try? FileManager.default.removeItem(at: previousOutputURL)
            }
            removeTempInputFiles()
            outputURL = mergedURL
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    /// ドラッグ&ドロップで一時ディレクトリに書き出された入力ファイルを結合後に削除する。
    private func removeTempInputFiles() {
        let tempDirPath = FileManager.default.temporaryDirectory.path
        for url in selectedURLs where url.path.hasPrefix(tempDirPath) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
