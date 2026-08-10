import Foundation
import PDFKit
import UIKit

enum SignatureServiceError: Error {
    case invalidInput
    case invalidPageIndex
    case fileWriteFailed(underlying: Error)
}

protocol SignatureServiceProtocol {
    func addSignature(
        to pdfURL: URL,
        signatureImage: UIImage,
        pageIndex: Int,
        rect: CGRect,
        outputURL: URL
    ) async throws -> URL
}

final class SignatureService: SignatureServiceProtocol {

    /// `rect` はページ左上を原点とするUIKit座標系（pt単位）で指定する。
    func addSignature(
        to pdfURL: URL,
        signatureImage: UIImage,
        pageIndex: Int,
        rect: CGRect,
        outputURL: URL
    ) async throws -> URL {
        guard let document = PDFDocument(url: pdfURL), document.pageCount > 0 else {
            throw SignatureServiceError.invalidInput
        }
        guard pageIndex >= 0, pageIndex < document.pageCount else {
            throw SignatureServiceError.invalidPageIndex
        }

        let renderer = UIGraphicsPDFRenderer(bounds: .zero)
        let pdfData = renderer.pdfData { context in
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index) else { continue }
                let pageRect = page.bounds(for: .mediaBox)
                context.beginPage(withBounds: pageRect, pageInfo: [:])

                let cgContext = context.cgContext
                cgContext.saveGState()
                cgContext.translateBy(x: 0, y: pageRect.size.height)
                cgContext.scaleBy(x: 1, y: -1)
                page.draw(with: .mediaBox, to: cgContext)
                cgContext.restoreGState()

                if index == pageIndex {
                    signatureImage.draw(in: rect)
                }
            }
        }

        do {
            try pdfData.write(to: outputURL, options: .atomic)
        } catch {
            throw SignatureServiceError.fileWriteFailed(underlying: error)
        }

        return outputURL
    }
}
