import Foundation
import PDFKit
import UIKit
import Vision

enum OCRServiceError: Error {
    case invalidInput
    case recognitionFailed
}

protocol OCRServiceProtocol {
    func extractText(from pdfURL: URL) async throws -> String
}

final class OCRService: OCRServiceProtocol {

    func extractText(from pdfURL: URL) async throws -> String {
        guard let document = PDFDocument(url: pdfURL), document.pageCount > 0 else {
            throw OCRServiceError.invalidInput
        }

        var recognizedPages: [String] = []

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex), let cgImage = renderPageImage(page)?.cgImage else {
                throw OCRServiceError.recognitionFailed
            }
            let pageText = try await recognizeText(in: cgImage)
            recognizedPages.append(pageText)
        }

        return recognizedPages.joined(separator: "\n\n")
    }

    private func recognizeText(in cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ja-JP", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// ページを等倍のビットマップとして描画する。OCR入力用の共通処理。
    private func renderPageImage(_ page: PDFPage) -> UIImage? {
        let pageRect = page.bounds(for: .mediaBox)
        guard pageRect.width > 0, pageRect.height > 0 else { return nil }

        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        return renderer.image { imageContext in
            UIColor.white.setFill()
            imageContext.fill(CGRect(origin: .zero, size: pageRect.size))

            let cgContext = imageContext.cgContext
            cgContext.translateBy(x: 0, y: pageRect.size.height)
            cgContext.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: cgContext)
        }
    }
}
