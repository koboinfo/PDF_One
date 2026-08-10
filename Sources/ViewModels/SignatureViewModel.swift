import Foundation
import PDFKit
import UIKit

@Observable
@MainActor
final class SignatureViewModel {

    static let previewWidth: CGFloat = 320

    var sourceURL: URL? {
        didSet {
            outputURL = nil
            signatureImage = nil
            loadDocument()
        }
    }

    private(set) var document: PDFDocument?
    private(set) var pageCount: Int = 0
    private(set) var pageThumbnail: UIImage?
    private(set) var pageSize: CGSize = .zero

    var pageIndex: Int = 0 {
        didSet { loadPageThumbnail() }
    }

    var signatureImage: UIImage? {
        didSet {
            guard let signatureImage, signatureImage.size.width > 0 else { return }
            let aspectRatio = signatureImage.size.height / signatureImage.size.width
            signatureSize = CGSize(width: signatureSize.width, height: signatureSize.width * aspectRatio)
        }
    }
    var signaturePosition: CGPoint = CGPoint(x: 20, y: 20)
    var signatureSize: CGSize = CGSize(width: 160, height: 80)

    var isProcessing: Bool = false
    var outputURL: URL?
    var errorMessage: String?

    private let signatureService: SignatureServiceProtocol

    init(signatureService: SignatureServiceProtocol = SignatureService()) {
        self.signatureService = signatureService
    }

    var previewHeight: CGFloat {
        guard pageSize.width > 0 else { return 0 }
        return pageSize.height * (Self.previewWidth / pageSize.width)
    }

    var canApplySignature: Bool {
        sourceURL != nil && signatureImage != nil
    }

    func applySignature() async {
        guard let sourceURL else {
            errorMessage = "署名対象のPDFファイルを選択してください。"
            return
        }
        guard let signatureImage else {
            errorMessage = "署名を描画してください。"
            return
        }
        guard pageSize.width > 0, pageSize.height > 0 else {
            errorMessage = "PDFページを読み込めませんでした。"
            return
        }

        isProcessing = true
        errorMessage = nil
        outputURL = nil

        let previewScale = pageSize.width / Self.previewWidth
        let rect = CGRect(
            x: signaturePosition.x * previewScale,
            y: signaturePosition.y * previewScale,
            width: signatureSize.width * previewScale,
            height: signatureSize.height * previewScale
        )

        do {
            let destinationURL = try SavedFileStore.directory()
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("pdf")

            outputURL = try await signatureService.addSignature(
                to: sourceURL,
                signatureImage: signatureImage,
                pageIndex: pageIndex,
                rect: rect,
                outputURL: destinationURL
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    private func loadDocument() {
        signaturePosition = CGPoint(x: 20, y: 20)

        guard let sourceURL, let document = PDFDocument(url: sourceURL), document.pageCount > 0 else {
            errorMessage = sourceURL != nil ? "PDFファイルを読み込めませんでした。" : nil
            document = nil
            pageCount = 0
            pageThumbnail = nil
            pageSize = .zero
            return
        }

        self.document = document
        pageCount = document.pageCount
        pageIndex = 0
    }

    private func loadPageThumbnail() {
        guard let document, pageIndex >= 0, pageIndex < document.pageCount,
              let page = document.page(at: pageIndex) else {
            pageThumbnail = nil
            pageSize = .zero
            return
        }

        pageSize = page.bounds(for: .mediaBox).size
        guard pageSize.width > 0, pageSize.height > 0 else {
            pageThumbnail = nil
            return
        }

        let thumbnailHeight = pageSize.height * (Self.previewWidth / pageSize.width)
        pageThumbnail = page.thumbnail(of: CGSize(width: Self.previewWidth, height: thumbnailHeight), for: .mediaBox)
    }
}
