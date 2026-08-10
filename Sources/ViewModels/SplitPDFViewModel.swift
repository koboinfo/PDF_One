import Foundation
import PDFKit

@Observable
final class SplitPDFViewModel {

    var sourceURL: URL? {
        didSet {
            outputURLs = []
            errorMessage = nil
            pageCount = sourceURL.flatMap { PDFDocument(url: $0)?.pageCount } ?? 0
        }
    }

    var pageCount: Int = 0
    var rangeText: String = ""
    var isProcessing: Bool = false
    var outputURLs: [URL] = []
    var errorMessage: String?

    private let pdfService: PDFServiceProtocol

    init(pdfService: PDFServiceProtocol = PDFService()) {
        self.pdfService = pdfService
    }

    func splitPDF() async {
        guard let sourceURL else {
            errorMessage = "分割するPDFファイルを選択してください。"
            return
        }

        guard let pageRanges = Self.parseRanges(rangeText, pageCount: pageCount), !pageRanges.isEmpty else {
            errorMessage = "分割範囲を正しく入力してください（例: 1-3, 4-5）。"
            return
        }

        isProcessing = true
        errorMessage = nil
        outputURLs = []

        let destinationDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
            outputURLs = try await pdfService.splitPDF(
                inputURL: sourceURL,
                pageRanges: pageRanges,
                outputDirectory: destinationDirectory
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    /// "1-3, 4-5" のようなカンマ区切りのページ範囲を1始まりの `ClosedRange` に変換する。不正な指定は `nil`。
    static func parseRanges(_ text: String, pageCount: Int) -> [ClosedRange<Int>]? {
        let components = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard !components.isEmpty else { return nil }

        var ranges: [ClosedRange<Int>] = []
        for component in components {
            let bounds = component.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
            switch bounds.count {
            case 1:
                guard let page = Int(bounds[0]), page >= 1, page <= pageCount else { return nil }
                ranges.append(page...page)
            case 2:
                guard let start = Int(bounds[0]), let end = Int(bounds[1]),
                      start >= 1, end <= pageCount, start <= end else { return nil }
                ranges.append(start...end)
            default:
                return nil
            }
        }
        return ranges
    }
}
