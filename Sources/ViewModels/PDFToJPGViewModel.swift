import Foundation
import UIKit

struct PDFImagePage: Identifiable {
    let id = UUID()
    let pageNumber: Int
    let image: UIImage
}

@Observable
final class PDFToJPGViewModel {

    var sourceURL: URL? {
        didSet {
            outputURLs = []
            errorMessage = nil
            pages = []
            guard let sourceURL else { return }
            Task { await loadPages(from: sourceURL) }
        }
    }

    var pages: [PDFImagePage] = []
    var isProcessing: Bool = false
    var outputURLs: [URL] = []
    var errorMessage: String?

    private let pdfService: PDFServiceProtocol

    init(pdfService: PDFServiceProtocol = PDFService()) {
        self.pdfService = pdfService
    }

    func exportAllAsJPEGs() async {
        guard !pages.isEmpty else {
            errorMessage = "変換するPDFファイルを選択してください。"
            return
        }

        isProcessing = true
        errorMessage = nil
        outputURLs = []

        let destinationDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

            var urls: [URL] = []
            for page in pages {
                guard let jpegData = page.image.jpegData(compressionQuality: 0.9) else {
                    throw PDFServiceError.unsupportedImageFormat
                }
                let url = destinationDirectory.appendingPathComponent("page_\(page.pageNumber).jpg")
                try jpegData.write(to: url, options: .atomic)
                urls.append(url)
            }
            outputURLs = urls
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    private func loadPages(from url: URL) async {
        isProcessing = true
        errorMessage = nil

        do {
            let images = try await pdfService.exportAsImages(inputURL: url)
            pages = images.enumerated().map { PDFImagePage(pageNumber: $0.offset + 1, image: $0.element) }
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }
}
