import Foundation

@Observable
@MainActor
final class OfficeToPDFViewModel {

    var selectedURL: URL? {
        didSet {
            outputURL = nil
            detectedFormat = Self.detectFormat(for: selectedURL)
        }
    }
    private(set) var detectedFormat: OfficeFormat?
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
        guard let detectedFormat else { return false }
        return detectedFormat == .word
    }

    func convert() async {
        guard let selectedURL, let detectedFormat else {
            errorMessage = "変換するWord/Excel/PowerPointファイルを選択してください。"
            return
        }

        isProcessing = true
        progress = 0
        errorMessage = nil

        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")

        async let conversionResult = pdfService.convertOfficeToPDF(
            inputURL: selectedURL,
            format: detectedFormat,
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

    private static func detectFormat(for url: URL?) -> OfficeFormat? {
        guard let url else { return nil }
        switch url.pathExtension.lowercased() {
        case "doc", "docx": return .word
        case "xls", "xlsx": return .excel
        case "ppt", "pptx": return .powerPoint
        default: return nil
        }
    }
}
