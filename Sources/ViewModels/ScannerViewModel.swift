import Foundation
import UIKit
import VisionKit

@Observable
@MainActor
final class ScannerViewModel {

    var isProcessing: Bool = false
    var outputURL: URL?
    var errorMessage: String?

    private let pdfService: PDFServiceProtocol

    init(pdfService: PDFServiceProtocol = PDFService()) {
        self.pdfService = pdfService
    }

    func savePDF(from scan: VNDocumentCameraScan) async {
        guard scan.pageCount > 0 else {
            errorMessage = "スキャンされたページがありません。"
            return
        }

        isProcessing = true
        errorMessage = nil
        outputURL = nil

        let workDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)

            var imageURLs: [URL] = []
            for pageIndex in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: pageIndex)
                guard let data = image.jpegData(compressionQuality: 0.9) else { continue }
                let imageURL = workDirectory.appendingPathComponent("page-\(pageIndex).jpg")
                try data.write(to: imageURL)
                imageURLs.append(imageURL)
            }

            let destinationURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("pdf")

            outputURL = try await pdfService.createPDF(fromImages: imageURLs, outputURL: destinationURL)
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }
}
