import Foundation

@Observable
@MainActor
final class WatermarkViewModel {

    var selectedURL: URL? {
        didSet { outputURL = nil }
    }
    var watermarkText: String = ""
    var isProcessing: Bool = false
    var outputURL: URL?
    var errorMessage: String?

    private let pdfService: PDFServiceProtocol

    init(pdfService: PDFServiceProtocol = PDFService()) {
        self.pdfService = pdfService
    }

    var canAddWatermark: Bool {
        selectedURL != nil && !watermarkText.isEmpty
    }

    func addWatermark() async {
        guard let selectedURL else {
            errorMessage = String(localized: "透かしを追加するPDFファイルを選択してください。")
            return
        }
        guard !watermarkText.isEmpty else {
            errorMessage = String(localized: "透かしに表示するテキストを入力してください。")
            return
        }

        isProcessing = true
        errorMessage = nil

        do {
            let destinationURL = try SavedFileStore.directory()
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("pdf")

            outputURL = try await pdfService.addWatermark(
                inputURL: selectedURL,
                text: watermarkText,
                outputURL: destinationURL
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }
}
