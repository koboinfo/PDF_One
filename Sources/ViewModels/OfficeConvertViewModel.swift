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
    private let progressStepCount = 20
    private let progressStepDurationNanoseconds: UInt64 = 100_000_000

    init(pdfService: PDFServiceProtocol = PDFService()) {
        self.pdfService = pdfService
    }

    var canConvert: Bool {
        selectedURL != nil
    }

    func convert() async {
        guard let selectedURL else {
            errorMessage = "変換するPDFファイルを選択してください。"
            return
        }

        isProcessing = true
        progress = 0
        errorMessage = nil

        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(selectedFormat.fileExtension)

        async let conversionResult = pdfService.convertToOffice(
            inputURL: selectedURL,
            format: selectedFormat,
            outputURL: destinationURL
        )

        for step in 1...progressStepCount {
            try? await Task.sleep(nanoseconds: progressStepDurationNanoseconds)
            progress = Double(step) / Double(progressStepCount)
        }

        do {
            outputURL = try await conversionResult
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }
}
