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

    init(pdfService: PDFServiceProtocol = PDFService()) {
        self.pdfService = pdfService
    }

    var canConvert: Bool {
        detectedFormat != nil
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

        do {
            outputURL = try await pdfService.convertOfficeToPDF(
                inputURL: selectedURL,
                format: detectedFormat,
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
