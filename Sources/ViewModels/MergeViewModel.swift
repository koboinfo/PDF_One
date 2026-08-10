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
            errorMessage = "結合するPDFファイルを選択してください。"
            return
        }

        isProcessing = true
        errorMessage = nil

        do {
            let destinationURL = try SavedFileStore.directory()
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("pdf")

            let mergedURL = try await pdfService.mergePDFs(
                inputURLs: selectedURLs,
                outputURL: destinationURL
            )
            outputURL = mergedURL
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }
}
