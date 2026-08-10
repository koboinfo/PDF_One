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
    case passwordProtectedFile
    case fileTooLarge(maxBytes: Int64)
}

extension PDFServiceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "ファイルを読み込めませんでした。ファイルが破損しているか、対応していない形式の可能性があります。"
        case .emptyDocumentSet:
            return "処理対象のページがありません。"
        case .fileWriteFailed:
            return "ファイルの書き出しに失敗しました。空き容量をご確認ください。"
        case .unsupportedImageFormat:
            return "対応していない画像形式が含まれています。"
        case .compressionFailed:
            return "PDFの圧縮に失敗しました。"
        case .imageExportFailed:
            return "画像の書き出しに失敗しました。"
        case .invalidPageRange:
            return "指定されたページ範囲が正しくありません。"
        case .protectionFailed:
            return "パスワードの設定に失敗しました。"
        case .incorrectPassword:
            return "パスワードが正しくありません。"
        case .watermarkFailed:
            return "透かしの追加に失敗しました。"
        case .officeConversionFailed:
            return "ファイルの変換に失敗しました。"
        case .passwordProtectedFile:
            return "パスワード保護されたPDFです。「パスワード設定」機能で保護を解除してから変換してください。"
        case .fileTooLarge(let maxBytes):
            let maxMB = maxBytes / 1_000_000
            return "ファイルサイズが大きすぎます（上限\(maxMB)MB）。ファイルを分割するか圧縮してからお試しください。"
        }
    }
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
    func convertToOffice(inputURL: URL, format: OfficeFormat, outputURL: URL, onProgress: (@Sendable (Double) -> Void)?) async throws -> URL
    func convertOfficeToPDF(inputURL: URL, format: OfficeFormat, outputURL: URL, onProgress: (@Sendable (Double) -> Void)?) async throws -> URL
}

/// PDFKit/CoreTextによるレンダリングはCPU負荷が高いため、actorとしてメインスレッド外で実行しUIフリーズを防ぐ。
/// 保持するミュータブルな状態はないため、同期的なページ操作ヘルパーは`nonisolated`にして呼び出し側での不要な`await`を避ける。
actor PDFService: PDFServiceProtocol {

    /// 変換対象として受け付ける入力ファイルサイズの上限。超過分はメモリを圧迫し得るため事前に弾く。
    static let maxInputFileSizeBytes: Int64 = 100_000_000

    /// ファイルサイズが上限を超えている場合に弾く。属性が取得できない場合は後続処理のエラーハンドリングに委ねる。
    private static func checkFileSize(of url: URL) throws {
        guard let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 else {
            return
        }
        guard fileSize <= maxInputFileSizeBytes else {
            throw PDFServiceError.fileTooLarge(maxBytes: maxInputFileSizeBytes)
        }
    }

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

    nonisolated func inspect(url: URL) throws -> PDFDocumentInfo {
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

    /// PDFの各ページから内容を抽出し、規格上有効なdocx/xlsx/pptxパッケージとして書き出す。
    /// Word/PowerPointは段落テキストの抽出、Excelは`extractTableRows`による表構造（行・列）の推定を行う。
    /// `onProgress`はページ処理が1件完了するたびに`0`〜`1`の値で呼ばれる。
    /// 各ページの処理を`autoreleasepool`で囲み、特にPowerPointの画像化で確保する一時ビットマップ・PNGデータを
    /// ページ処理直後に解放してピーク時メモリを抑える。
    func convertToOffice(
        inputURL: URL,
        format: OfficeFormat,
        outputURL: URL,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        try Self.checkFileSize(of: inputURL)

        guard let document = PDFDocument(url: inputURL), document.pageCount > 0 else {
            throw PDFServiceError.invalidInput
        }

        guard !document.isLocked else {
            throw PDFServiceError.passwordProtectedFile
        }

        let pageCount = document.pageCount
        let packageData: Data
        switch format {
        case .word:
            var pageTexts: [String] = []
            pageTexts.reserveCapacity(pageCount)
            for pageIndex in 0..<pageCount {
                autoreleasepool {
                    pageTexts.append(document.page(at: pageIndex)?.string ?? "")
                }
                onProgress?(Double(pageIndex + 1) / Double(pageCount))
            }
            packageData = OfficeDocumentBuilder.makeDocx(pageTexts: pageTexts)
        case .excel:
            var sheets: [[[String]]] = []
            sheets.reserveCapacity(pageCount)
            for pageIndex in 0..<pageCount {
                autoreleasepool {
                    sheets.append(document.page(at: pageIndex).map(Self.extractTableRows) ?? [])
                }
                onProgress?(Double(pageIndex + 1) / Double(pageCount))
            }
            packageData = OfficeDocumentBuilder.makeXlsx(sheets: sheets)
        case .powerPoint:
            var slides: [OfficeDocumentBuilder.SlideContent] = []
            slides.reserveCapacity(pageCount)
            for pageIndex in 0..<pageCount {
                autoreleasepool {
                    if let page = document.page(at: pageIndex),
                       let image = renderPageImage(page),
                       let pngData = image.pngData() {
                        slides.append(.image(
                            data: pngData,
                            pixelWidth: Int(image.size.width * image.scale),
                            pixelHeight: Int(image.size.height * image.scale)
                        ))
                    }
                }
                onProgress?(Double(pageIndex + 1) / Double(pageCount))
            }
            guard !slides.isEmpty else {
                throw PDFServiceError.officeConversionFailed
            }
            packageData = OfficeDocumentBuilder.makePptx(slides: slides)
        }

        do {
            try packageData.write(to: outputURL, options: .atomic)
        } catch {
            throw PDFServiceError.officeConversionFailed
        }

        return outputURL
    }

    /// iOSには`NSAttributedString`でOOXMLを直接読み込む公開APIが存在しない（macOS/AppKit限定）ため、
    /// docx/xlsx/pptxいずれも自前のZIP/XMLパーサー（`OfficeDocumentReader`系）で内容を取り出し、PDFとして再描画する。
    /// `onProgress`は解析対象のページ/シート/スライド単位で`0`〜`1`の値を通知する。
    func convertOfficeToPDF(
        inputURL: URL,
        format: OfficeFormat,
        outputURL: URL,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        try Self.checkFileSize(of: inputURL)

        let sourceData: Data
        do {
            sourceData = try Data(contentsOf: inputURL)
        } catch {
            throw PDFServiceError.invalidInput
        }

        guard !Self.isEncryptedOfficeContainer(sourceData) else {
            throw PDFServiceError.passwordProtectedFile
        }

        let pdfData: Data
        switch format {
        case .word:
            let paragraphs = try Self.readOffice { try OfficeDocumentReader.readDocxParagraphs(from: sourceData) }
            guard paragraphs.contains(where: { !$0.isEmpty }) else {
                throw PDFServiceError.emptyDocumentSet
            }
            pdfData = Self.renderPDF(from: Self.makeAttributedString(fromParagraphs: paragraphs), onProgress: onProgress)
        case .excel:
            let sheets = try Self.readOffice { try OfficeSpreadsheetReader.readSheets(from: sourceData) }
            pdfData = Self.renderExcelPDF(sheets: sheets, onProgress: onProgress)
        case .powerPoint:
            let (slideSizeEMU, slides) = try Self.readOffice { try OfficePresentationReader.readSlides(from: sourceData) }
            pdfData = Self.renderPptxPDF(slideSizeEMU: slideSizeEMU, slides: slides, onProgress: onProgress)
        }

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

    private static func readOffice<T>(_ body: () throws -> T) throws -> T {
        do {
            return try body()
        } catch {
            throw PDFServiceError.officeConversionFailed
        }
    }

    /// Microsoft Officeのパスワード保護は、暗号化ZIPではなくOLE構造化ストレージ（CFBF）でZIPパッケージ全体を
    /// ラップする方式（MS-OFFCRYPTO）を採る。通常のdocx/xlsx/pptxは`PK\x03\x04`で始まるZIPだが、
    /// パスワード保護されたファイルはCFBFシグネチャで始まるため、ZIP解析を試みる前に先頭バイト列で判定する。
    private static func isEncryptedOfficeContainer(_ data: Data) -> Bool {
        let cfbSignature: [UInt8] = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]
        guard data.count >= cfbSignature.count else { return false }
        return data.prefix(cfbSignature.count).elementsEqual(cfbSignature)
    }

    /// PDFページの文字位置（`characterBounds`）から行・列を推定し、表形式の文字列グリッドとして返す。
    /// 同一Y座標付近の文字を1行にまとめ、行内で一定以上の水平方向の空白がある箇所を列の区切りとみなす簡易ヒューリスティクス。
    /// 罫線を検出しているわけではないため、テキストの整列が崩れているPDFでは列がずれることがある。
    private static func extractTableRows(from page: PDFPage) -> [[String]] {
        let characterCount = page.numberOfCharacters
        guard characterCount > 0, let pageString = page.string else { return [] }

        let nsString = pageString as NSString
        let length = min(characterCount, nsString.length)

        struct PositionedCharacter {
            let text: String
            let rect: CGRect
        }

        var positioned: [PositionedCharacter] = []
        positioned.reserveCapacity(length)
        for index in 0..<length {
            let rect = page.characterBounds(at: index)
            guard rect.width > 0 || rect.height > 0 else { continue }
            positioned.append(PositionedCharacter(text: nsString.substring(with: NSRange(location: index, length: 1)), rect: rect))
        }
        guard !positioned.isEmpty else { return [] }

        let lineYTolerance: CGFloat = 3
        var lines: [[PositionedCharacter]] = []
        for item in positioned {
            if let lastItem = lines.last?.last, abs(item.rect.midY - lastItem.rect.midY) <= lineYTolerance {
                lines[lines.count - 1].append(item)
            } else {
                lines.append([item])
            }
        }

        let cellGapThreshold: CGFloat = 10
        return lines.map { line in
            var cells: [String] = []
            var currentCellText = ""
            var previousMaxX: CGFloat?

            for item in line {
                // PDFKitは離れた単語間の空白を1つの幅広い空白グリフへ丸めて表現することがあるため、
                // 空白文字自体の幅が大きい場合もそこで列を区切る（隣接矩形間の隙間だけでは検出できない）。
                let isWideWhitespace = item.rect.width > cellGapThreshold && item.text.trimmingCharacters(in: .whitespaces).isEmpty
                if isWideWhitespace {
                    if !currentCellText.trimmingCharacters(in: .whitespaces).isEmpty {
                        cells.append(currentCellText.trimmingCharacters(in: .whitespaces))
                        currentCellText = ""
                    }
                    previousMaxX = item.rect.maxX
                    continue
                }

                if let previousMaxX, item.rect.minX - previousMaxX > cellGapThreshold {
                    cells.append(currentCellText.trimmingCharacters(in: .whitespaces))
                    currentCellText = ""
                }
                currentCellText += item.text
                previousMaxX = item.rect.maxX
            }

            let trimmedTail = currentCellText.trimmingCharacters(in: .whitespaces)
            if !trimmedTail.isEmpty || cells.isEmpty {
                cells.append(trimmedTail)
            }
            return cells
        }
    }

    /// シート名を見出しとして各シートを新しいページから描画し、セルをグリッド線付きの表として並べる。
    /// 列幅は40〜150ptにクランプするため、列数が極端に多いシートは右側が用紙外にはみ出す場合がある。
    /// シート1件の描画完了ごとに`onProgress`を呼び、描画中に確保する一時オブジェクトを`autoreleasepool`で解放する。
    private static func renderExcelPDF(sheets: [OfficeSpreadsheetReader.Sheet], onProgress: (@Sendable (Double) -> Void)? = nil) -> Data {
        let pageSize = CGSize(width: 792, height: 612)
        let margin: CGFloat = 36
        let contentWidth = pageSize.width - margin * 2
        let rowHeight: CGFloat = 20
        let cellFont = UIFont.systemFont(ofSize: 9)
        let titleFont = UIFont.boldSystemFont(ofSize: 14)
        let gridColor = UIColor(white: 0.7, alpha: 1)
        let sheetCount = max(sheets.count, 1)

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        return renderer.pdfData { context in
            for (sheetIndex, sheet) in sheets.enumerated() {
                autoreleasepool {
                    context.beginPage()
                    var cursorY = margin

                    (sheet.name as NSString).draw(at: CGPoint(x: margin, y: cursorY), withAttributes: [.font: titleFont])
                    cursorY += titleFont.lineHeight + 12

                    let columnCount = max(sheet.rows.map(\.count).max() ?? 0, 1)
                    let columnWidth = min(150, max(40, contentWidth / CGFloat(columnCount)))

                    for row in sheet.rows {
                        if cursorY + rowHeight > pageSize.height - margin {
                            context.beginPage()
                            cursorY = margin
                        }

                        var cursorX = margin
                        for columnIndex in 0..<columnCount {
                            let cellRect = CGRect(x: cursorX, y: cursorY, width: columnWidth, height: rowHeight)
                            gridColor.setStroke()
                            UIBezierPath(rect: cellRect).stroke()

                            if columnIndex < row.count, !row[columnIndex].isEmpty {
                                (row[columnIndex] as NSString).draw(
                                    in: cellRect.insetBy(dx: 3, dy: 3),
                                    withAttributes: [.font: cellFont]
                                )
                            }
                            cursorX += columnWidth
                        }
                        cursorY += rowHeight
                    }
                }
                onProgress?(Double(sheetIndex + 1) / Double(sheetCount))
            }
        }
    }

    /// スライド1枚を1ページとして描画する。テキストは位置・サイズのみ再現しフォント装飾は既定値、画像は原寸をフレームに合わせて配置する。
    /// スライド1枚の描画完了ごとに`onProgress`を呼ぶ。`UIImage(data:)`によるデコード結果は`autoreleasepool`で
    /// スライドごとに解放し、スライド枚数分の画像を同時に保持しないようにする。
    private static func renderPptxPDF(slideSizeEMU: CGSize, slides: [OfficePresentationReader.Slide], onProgress: (@Sendable (Double) -> Void)? = nil) -> Data {
        let emuPerPoint: CGFloat = 12700
        let fallbackSizeEMU = CGSize(width: 12_192_000, height: 6_858_000)
        let effectiveSizeEMU = (slideSizeEMU.width > 0 && slideSizeEMU.height > 0) ? slideSizeEMU : fallbackSizeEMU
        let pageSize = CGSize(width: effectiveSizeEMU.width / emuPerPoint, height: effectiveSizeEMU.height / emuPerPoint)
        let bodyFont = UIFont.systemFont(ofSize: 14)
        let slideCount = max(slides.count, 1)

        func pointRect(fromEMU emuRect: CGRect) -> CGRect {
            CGRect(
                x: emuRect.origin.x / emuPerPoint,
                y: emuRect.origin.y / emuPerPoint,
                width: emuRect.width / emuPerPoint,
                height: emuRect.height / emuPerPoint
            )
        }

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        return renderer.pdfData { context in
            for (slideIndex, slide) in slides.enumerated() {
                autoreleasepool {
                    context.beginPage()
                    for element in slide.elements {
                        switch element {
                        case .text(let paragraphs, let frameEMU):
                            (paragraphs.joined(separator: "\n") as NSString).draw(
                                in: pointRect(fromEMU: frameEMU),
                                withAttributes: [.font: bodyFont]
                            )
                        case .image(let data, let frameEMU):
                            guard let image = UIImage(data: data) else { continue }
                            image.draw(in: pointRect(fromEMU: frameEMU))
                        }
                    }
                }
                onProgress?(Double(slideIndex + 1) / Double(slideCount))
            }
        }
    }

    private static func makeAttributedString(fromParagraphs paragraphs: [String]) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = 8
        return NSAttributedString(
            string: paragraphs.joined(separator: "\n"),
            attributes: [.font: UIFont.systemFont(ofSize: 12), .paragraphStyle: paragraphStyle]
        )
    }

    /// US Letterサイズ・上下左右余白48ptでCoreTextのフレームセッターを使いページ分割しながら描画する。
    /// 最大ページ数は暴走防止のための安全弁。ページ描画完了ごとに文字位置ベースの進捗（`currentLocation / fullLength`）を通知する。
    private static func renderPDF(from attributedString: NSAttributedString, onProgress: (@Sendable (Double) -> Void)? = nil) -> Data {
        let pageSize = CGSize(width: 612, height: 792)
        let margin: CGFloat = 48
        let textRect = CGRect(x: margin, y: margin, width: pageSize.width - margin * 2, height: pageSize.height - margin * 2)
        let path = CGPath(rect: textRect, transform: nil)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let fullLength = max(attributedString.length, 1)
        let maxPageCount = 2000

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        return renderer.pdfData { context in
            var currentLocation = 0
            var renderedPageCount = 0

            repeat {
                autoreleasepool {
                    context.beginPage()

                    let cgContext = context.cgContext
                    cgContext.saveGState()
                    cgContext.translateBy(x: 0, y: pageSize.height)
                    cgContext.scaleBy(x: 1, y: -1)

                    let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: currentLocation, length: 0), path, nil)
                    CTFrameDraw(frame, cgContext)
                    cgContext.restoreGState()

                    let frameRange = CTFrameGetVisibleStringRange(frame)
                    if frameRange.length > 0 {
                        currentLocation += frameRange.length
                        renderedPageCount += 1
                    } else {
                        currentLocation = fullLength
                    }
                }
                onProgress?(min(Double(currentLocation) / Double(fullLength), 1))
            } while currentLocation < fullLength && renderedPageCount < maxPageCount
        }
    }

    /// `newOrder` に列挙されたページ番号（0始まり）の順序・部分集合で構成された新しい `PDFDocument` を返す。
    /// 除外されたページは削除、重複や並び替えはそのまま反映される。
    /// ページ配列の操作のみで重い描画を伴わないため`nonisolated`とし、呼び出し側での`await`を不要にする。
    nonisolated func reorderPages(in document: PDFDocument, to newOrder: [Int]) -> PDFDocument {
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
    nonisolated func rotatePage(_ page: PDFPage, byDegrees degrees: Int) {
        guard degrees != 0 else { return }
        let normalizedDelta = ((degrees % 360) + 360) % 360
        page.rotation = (page.rotation + normalizedDelta) % 360
    }

    /// 指定したページを `document` から削除する。
    nonisolated func deletePages(from document: PDFDocument, at indices: IndexSet) {
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
