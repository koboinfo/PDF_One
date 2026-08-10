import CoreText
import Foundation
import PDFKit
import UIKit

enum PDFServiceError: Error {
    case invalidInput
    case emptyDocumentSet
    case fileWriteFailed(underlying: Error)
    case unsupportedImageFormat
    case compressionFailed
    case imageExportFailed
    case invalidPageRange
    case protectionFailed
    case incorrectPassword
    case watermarkFailed
    case officeConversionFailed
    case unsupportedOfficeFormat
}

enum OfficeFormat: String, CaseIterable, Hashable {
    case word
    case excel
    case powerPoint

    var fileExtension: String {
        switch self {
        case .word: return "docx"
        case .excel: return "xlsx"
        case .powerPoint: return "pptx"
        }
    }

    var label: String {
        switch self {
        case .word: return "Word"
        case .excel: return "Excel"
        case .powerPoint: return "PowerPoint"
        }
    }
}

enum PDFCompressionQuality: Hashable {
    case low
    case medium
    case high
    case custom(jpegQuality: CGFloat)
}

struct PDFDocumentInfo {
    let pageCount: Int
    let fileSizeBytes: Int64
    let title: String?
}

/// 編集後PDFの1ページ分の指定。配列内での並び順がそのまま出力PDFのページ順になる。
struct PDFPageEdit {
    let sourcePageIndex: Int
    let rotationDelta: Int

    init(sourcePageIndex: Int, rotationDelta: Int = 0) {
        self.sourcePageIndex = sourcePageIndex
        self.rotationDelta = rotationDelta
    }
}

protocol PDFServiceProtocol {
    func mergePDFs(inputURLs: [URL], outputURL: URL) async throws -> URL
    func createPDF(fromImages imageURLs: [URL], outputURL: URL) async throws -> URL
    func compressPDF(inputURL: URL, outputURL: URL, quality: PDFCompressionQuality) async throws -> URL
    func inspect(url: URL) throws -> PDFDocumentInfo
    func generateEditedPDF(inputURL: URL, pageEdits: [PDFPageEdit], outputURL: URL) async throws -> URL
    func extractPages(inputURL: URL, pageIndices: [Int], outputURL: URL) async throws -> URL
    func exportAsImages(inputURL: URL) async throws -> [UIImage]
    func splitPDF(inputURL: URL, pageRanges: [ClosedRange<Int>], outputDirectory: URL) async throws -> [URL]
    func protectPDF(inputURL: URL, outputURL: URL, password: String) async throws -> URL
    func unlockPDF(inputURL: URL, outputURL: URL, password: String) async throws -> URL
    func addWatermark(inputURL: URL, text: String, outputURL: URL) async throws -> URL
    func convertToOffice(inputURL: URL, format: OfficeFormat, outputURL: URL) async throws -> URL
    func convertOfficeToPDF(inputURL: URL, format: OfficeFormat, outputURL: URL) async throws -> URL
}

final class PDFService: PDFServiceProtocol {

    func mergePDFs(inputURLs: [URL], outputURL: URL) async throws -> URL {
        guard !inputURLs.isEmpty else {
            throw PDFServiceError.emptyDocumentSet
        }

        let mergedDocument = PDFDocument()
        var insertIndex = 0

        for inputURL in inputURLs {
            guard let sourceDocument = PDFDocument(url: inputURL) else {
                throw PDFServiceError.invalidInput
            }

            for pageIndex in 0..<sourceDocument.pageCount {
                guard let page = sourceDocument.page(at: pageIndex) else {
                    continue
                }
                mergedDocument.insert(page, at: insertIndex)
                insertIndex += 1
            }
        }

        guard mergedDocument.pageCount > 0 else {
            throw PDFServiceError.emptyDocumentSet
        }

        guard mergedDocument.write(to: outputURL) else {
            throw PDFServiceError.fileWriteFailed(
                underlying: NSError(domain: "PDFService.mergePDFs", code: -1)
            )
        }

        return outputURL
    }

    func createPDF(fromImages imageURLs: [URL], outputURL: URL) async throws -> URL {
        guard !imageURLs.isEmpty else {
            throw PDFServiceError.emptyDocumentSet
        }

        var images: [UIImage] = []
        for imageURL in imageURLs {
            guard let data = try? Data(contentsOf: imageURL),
                  let image = UIImage(data: data) else {
                throw PDFServiceError.unsupportedImageFormat
            }
            images.append(image)
        }

        let renderer = UIGraphicsPDFRenderer(bounds: .zero)
        let pdfData = renderer.pdfData { context in
            for image in images {
                let pageRect = CGRect(origin: .zero, size: image.size)
                context.beginPage(withBounds: pageRect, pageInfo: [:])
                image.draw(in: pageRect)
            }
        }

        do {
            try pdfData.write(to: outputURL, options: .atomic)
        } catch {
            throw PDFServiceError.fileWriteFailed(underlying: error)
        }

        return outputURL
    }

    func compressPDF(inputURL: URL, outputURL: URL, quality: PDFCompressionQuality) async throws -> URL {
        guard let sourceDocument = PDFDocument(url: inputURL), sourceDocument.pageCount > 0 else {
            throw PDFServiceError.compressionFailed
        }

        let jpegQuality = Self.jpegQuality(for: quality)
        var renderFailed = false

        let renderer = UIGraphicsPDFRenderer(bounds: .zero)
        let pdfData = renderer.pdfData { context in
            for pageIndex in 0..<sourceDocument.pageCount {
                guard let page = sourceDocument.page(at: pageIndex), let pageImage = renderPageImage(page) else {
                    renderFailed = true
                    continue
                }

                let pageRect = page.bounds(for: .mediaBox)

                guard let jpegData = pageImage.jpegData(compressionQuality: jpegQuality),
                      let compressedImage = UIImage(data: jpegData) else {
                    renderFailed = true
                    continue
                }

                context.beginPage(withBounds: pageRect, pageInfo: [:])
                compressedImage.draw(in: CGRect(origin: .zero, size: pageRect.size))
            }
        }

        guard !renderFailed, !pdfData.isEmpty else {
            throw PDFServiceError.compressionFailed
        }

        do {
            try pdfData.write(to: outputURL, options: .atomic)
        } catch {
            throw PDFServiceError.compressionFailed
        }

        return outputURL
    }

    func inspect(url: URL) throws -> PDFDocumentInfo {
        fatalError("not implemented")
    }

    func generateEditedPDF(inputURL: URL, pageEdits: [PDFPageEdit], outputURL: URL) async throws -> URL {
        guard !pageEdits.isEmpty else {
            throw PDFServiceError.emptyDocumentSet
        }

        guard let sourceDocument = PDFDocument(url: inputURL) else {
            throw PDFServiceError.invalidInput
        }

        guard pageEdits.allSatisfy({ $0.sourcePageIndex >= 0 && $0.sourcePageIndex < sourceDocument.pageCount }) else {
            throw PDFServiceError.invalidInput
        }

        let editedDocument = reorderPages(in: sourceDocument, to: pageEdits.map(\.sourcePageIndex))

        for (index, edit) in pageEdits.enumerated() {
            guard let page = editedDocument.page(at: index) else { continue }
            rotatePage(page, byDegrees: edit.rotationDelta)
        }

        guard editedDocument.pageCount > 0 else {
            throw PDFServiceError.emptyDocumentSet
        }

        guard editedDocument.write(to: outputURL) else {
            throw PDFServiceError.fileWriteFailed(
                underlying: NSError(domain: "PDFService.generateEditedPDF", code: -1)
            )
        }

        return outputURL
    }

    func extractPages(inputURL: URL, pageIndices: [Int], outputURL: URL) async throws -> URL {
        guard !pageIndices.isEmpty else {
            throw PDFServiceError.emptyDocumentSet
        }

        let pageEdits = pageIndices.map { PDFPageEdit(sourcePageIndex: $0) }
        return try await generateEditedPDF(inputURL: inputURL, pageEdits: pageEdits, outputURL: outputURL)
    }

    func exportAsImages(inputURL: URL) async throws -> [UIImage] {
        guard let document = PDFDocument(url: inputURL), document.pageCount > 0 else {
            throw PDFServiceError.invalidInput
        }

        var images: [UIImage] = []
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex), let image = renderPageImage(page) else {
                throw PDFServiceError.imageExportFailed
            }
            images.append(image)
        }

        return images
    }

    /// `pageRanges` は1始まりのページ番号（例: `1...3`）。範囲ごとに個別のPDFファイルを `outputDirectory` に書き出す。
    func splitPDF(inputURL: URL, pageRanges: [ClosedRange<Int>], outputDirectory: URL) async throws -> [URL] {
        guard !pageRanges.isEmpty else {
            throw PDFServiceError.invalidPageRange
        }

        guard let sourceDocument = PDFDocument(url: inputURL), sourceDocument.pageCount > 0 else {
            throw PDFServiceError.invalidInput
        }

        guard pageRanges.allSatisfy({ $0.lowerBound >= 1 && $0.upperBound <= sourceDocument.pageCount }) else {
            throw PDFServiceError.invalidPageRange
        }

        var outputURLs: [URL] = []
        for (rangeIndex, range) in pageRanges.enumerated() {
            let splitDocument = PDFDocument()
            var insertIndex = 0
            for pageNumber in range {
                guard let page = sourceDocument.page(at: pageNumber - 1) else { continue }
                splitDocument.insert(page, at: insertIndex)
                insertIndex += 1
            }

            let outputURL = outputDirectory.appendingPathComponent("split_\(rangeIndex + 1).pdf")
            guard splitDocument.write(to: outputURL) else {
                throw PDFServiceError.fileWriteFailed(
                    underlying: NSError(domain: "PDFService.splitPDF", code: -1)
                )
            }
            outputURLs.append(outputURL)
        }

        return outputURLs
    }

    func protectPDF(inputURL: URL, outputURL: URL, password: String) async throws -> URL {
        guard !password.isEmpty else {
            throw PDFServiceError.invalidInput
        }

        guard let document = PDFDocument(url: inputURL), document.pageCount > 0 else {
            throw PDFServiceError.invalidInput
        }

        let options: [PDFDocumentWriteOption: Any] = [
            .userPasswordOption: password,
            .ownerPasswordOption: password
        ]

        guard document.write(to: outputURL, withOptions: options) else {
            throw PDFServiceError.protectionFailed
        }

        return outputURL
    }

    func unlockPDF(inputURL: URL, outputURL: URL, password: String) async throws -> URL {
        guard let document = PDFDocument(url: inputURL) else {
            throw PDFServiceError.invalidInput
        }

        if document.isLocked {
            guard document.unlock(withPassword: password) else {
                throw PDFServiceError.incorrectPassword
            }
        }

        // `document`自体を書き出すと暗号化情報が引き継がれ再ロックされるため、
        // ページだけを新規PDFDocumentへ移し替えて暗号化のない状態で書き出す。
        let unlockedDocument = reorderPages(in: document, to: Array(0..<document.pageCount))

        guard unlockedDocument.write(to: outputURL) else {
            throw PDFServiceError.fileWriteFailed(
                underlying: NSError(domain: "PDFService.unlockPDF", code: -1)
            )
        }

        return outputURL
    }

    /// 全ページのコンテンツをベクターのまま再描画し、中央に回転・半透明のテキストを重ねて透かしを付与する。
    func addWatermark(inputURL: URL, text: String, outputURL: URL) async throws -> URL {
        guard !text.isEmpty else {
            throw PDFServiceError.invalidInput
        }

        guard let sourceDocument = PDFDocument(url: inputURL), sourceDocument.pageCount > 0 else {
            throw PDFServiceError.invalidInput
        }

        let renderer = UIGraphicsPDFRenderer(bounds: .zero)
        let pdfData = renderer.pdfData { context in
            for pageIndex in 0..<sourceDocument.pageCount {
                guard let page = sourceDocument.page(at: pageIndex) else { continue }
                let pageRect = page.bounds(for: .mediaBox)
                context.beginPage(withBounds: pageRect, pageInfo: [:])

                let cgContext = context.cgContext
                cgContext.saveGState()
                cgContext.translateBy(x: 0, y: pageRect.size.height)
                cgContext.scaleBy(x: 1, y: -1)
                page.draw(with: .mediaBox, to: cgContext)
                cgContext.restoreGState()

                Self.drawWatermarkText(text, in: pageRect)
            }
        }

        guard !pdfData.isEmpty else {
            throw PDFServiceError.watermarkFailed
        }

        do {
            try pdfData.write(to: outputURL, options: .atomic)
        } catch {
            throw PDFServiceError.watermarkFailed
        }

        return outputURL
    }

    /// PDFの各ページからテキストを抽出し、規格上有効なdocx/xlsx/pptxパッケージとして書き出す。
    /// 表構造（Excel）やページレイアウト画像（PowerPoint）の再現は`PDFTableExtractor`等の専用ロジックが担う。
    func convertToOffice(inputURL: URL, format: OfficeFormat, outputURL: URL) async throws -> URL {
        guard let document = PDFDocument(url: inputURL), document.pageCount > 0 else {
            throw PDFServiceError.invalidInput
        }

        let pageTexts = (0..<document.pageCount).map { document.page(at: $0)?.string ?? "" }

        let packageData: Data
        switch format {
        case .word:
            packageData = OfficeDocumentBuilder.makeDocx(pageTexts: pageTexts)
        case .excel:
            let rows = pageTexts.flatMap { $0.components(separatedBy: .newlines) }.map { [$0] }
            packageData = OfficeDocumentBuilder.makeXlsx(sheets: [rows])
        case .powerPoint:
            let slides = pageTexts.map { OfficeDocumentBuilder.SlideContent.text($0) }
            packageData = OfficeDocumentBuilder.makePptx(slides: slides)
        }

        do {
            try packageData.write(to: outputURL, options: .atomic)
        } catch {
            throw PDFServiceError.officeConversionFailed
        }

        return outputURL
    }

    /// Word(.docx)は`NSAttributedString`でOOXMLを読み込みCoreTextでページ分割して描画する。
    /// Excel/PowerPointの読み込みにはiOS標準APIが存在しないため、専用パーサー実装まで非対応。
    func convertOfficeToPDF(inputURL: URL, format: OfficeFormat, outputURL: URL) async throws -> URL {
        guard format == .word else {
            throw PDFServiceError.unsupportedOfficeFormat
        }

        let attributedString: NSAttributedString
        do {
            attributedString = try NSAttributedString(
                url: inputURL,
                options: [.documentType: NSAttributedString.DocumentType.officeOpenXML],
                documentAttributes: nil
            )
        } catch {
            throw PDFServiceError.officeConversionFailed
        }

        guard !attributedString.string.isEmpty else {
            throw PDFServiceError.emptyDocumentSet
        }

        let pdfData = Self.renderPDF(from: attributedString)
        guard !pdfData.isEmpty else {
            throw PDFServiceError.officeConversionFailed
        }

        do {
            try pdfData.write(to: outputURL, options: .atomic)
        } catch {
            throw PDFServiceError.officeConversionFailed
        }

        return outputURL
    }

    /// US Letterサイズ・上下左右余白48ptでCoreTextのフレームセッターを使いページ分割しながら描画する。
    /// 最大ページ数は暴走防止のための安全弁。
    private static func renderPDF(from attributedString: NSAttributedString) -> Data {
        let pageSize = CGSize(width: 612, height: 792)
        let margin: CGFloat = 48
        let textRect = CGRect(x: margin, y: margin, width: pageSize.width - margin * 2, height: pageSize.height - margin * 2)
        let path = CGPath(rect: textRect, transform: nil)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let fullLength = attributedString.length
        let maxPageCount = 2000

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        return renderer.pdfData { context in
            var currentLocation = 0
            var renderedPageCount = 0

            repeat {
                context.beginPage()

                let cgContext = context.cgContext
                cgContext.saveGState()
                cgContext.translateBy(x: 0, y: pageSize.height)
                cgContext.scaleBy(x: 1, y: -1)

                let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: currentLocation, length: 0), path, nil)
                CTFrameDraw(frame, cgContext)
                cgContext.restoreGState()

                let frameRange = CTFrameGetVisibleStringRange(frame)
                guard frameRange.length > 0 else { break }

                currentLocation += frameRange.length
                renderedPageCount += 1
            } while currentLocation < fullLength && renderedPageCount < maxPageCount
        }
    }

    /// `newOrder` に列挙されたページ番号（0始まり）の順序・部分集合で構成された新しい `PDFDocument` を返す。
    /// 除外されたページは削除、重複や並び替えはそのまま反映される。
    func reorderPages(in document: PDFDocument, to newOrder: [Int]) -> PDFDocument {
        let reordered = PDFDocument()
        var insertIndex = 0
        for sourceIndex in newOrder {
            guard sourceIndex >= 0, sourceIndex < document.pageCount,
                  let page = document.page(at: sourceIndex) else {
                continue
            }
            reordered.insert(page, at: insertIndex)
            insertIndex += 1
        }
        return reordered
    }

    /// ページの現在の回転角に `degrees` を加算する（90度単位を想定）。
    func rotatePage(_ page: PDFPage, byDegrees degrees: Int) {
        guard degrees != 0 else { return }
        let normalizedDelta = ((degrees % 360) + 360) % 360
        page.rotation = (page.rotation + normalizedDelta) % 360
    }

    /// 指定したページを `document` から削除する。
    func deletePages(from document: PDFDocument, at indices: IndexSet) {
        for index in indices.sorted(by: >) {
            guard index >= 0, index < document.pageCount else { continue }
            document.removePage(at: index)
        }
    }

    /// ページを等倍のビットマップとして描画する。JPEG化や画像抽出の共通処理。
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

    /// 現在のグラフィックスコンテキストにページ中央から45度回転した半透明テキストを描画する。
    private static func drawWatermarkText(_ text: String, in pageRect: CGRect) {
        let fontSize = max(min(pageRect.width, pageRect.height) * 0.1, 12)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: fontSize),
            .foregroundColor: UIColor.gray.withAlphaComponent(0.35)
        ]
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedText.size()

        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()
        context?.translateBy(x: pageRect.midX, y: pageRect.midY)
        context?.rotate(by: -.pi / 4)
        attributedText.draw(in: CGRect(
            x: -textSize.width / 2,
            y: -textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        ))
        context?.restoreGState()
    }

    private static func jpegQuality(for quality: PDFCompressionQuality) -> CGFloat {
        switch quality {
        case .low:
            return 0.3
        case .medium:
            return 0.5
        case .high:
            return 0.7
        case .custom(let jpegQuality):
            return jpegQuality
        }
    }
}
