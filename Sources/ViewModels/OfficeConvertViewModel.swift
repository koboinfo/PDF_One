import Foundation

@Observable
@MainActor
final class OfficeConvertViewModel {

    var selectedURL: URL? {
        didSet { outputURL = nil }
    }
    var selectedFormat: OfficeFormat = .word
    var isProcessing: Bool = false
    var progress: Double = 0
    var outputURL: URL?
    var errorMessage: String?

    private let pdfService: PDFServiceProtocol

    init(pdfService: PDFServiceProtocol = PDFService()) {
        self.pdfService = pdfService
    }

    var canConvert: Bool {
        selectedURL != nil
    }

    func convert() async {
        guard let selectedURL else {
            errorMessage = String(localized: "変換するPDFファイルを選択してください。")
            return
        }

        isProcessing = true
        progress = 0
        errorMessage = nil
        AdMobInterstitialManager.shared.preloadAd()

        do {
            let destinationURL = try SavedFileStore.directory(for: .office)
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(selectedFormat.fileExtension)

            outputURL = try await pdfService.convertToOffice(
                inputURL: selectedURL,
                format: selectedFormat,
                outputURL: destinationURL
            ) { [weak self] value in
                Task { @MainActor in
                    self?.progress = value
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }
}
