import XCTest
import PDFKit
import UIKit
@testable import PDF_One

final class PDFServiceTests: XCTestCase {
    private var sut: PDFService!
    private var workDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = PDFService()
        workDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PDFServiceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: workDirectory)
        sut = nil
        workDirectory = nil
        try super.tearDownWithError()
    }

    // MARK: - mergePDFs

    func testMergePDFsCombinesPageCounts() async throws {
        let firstPDF = try makePDFFile(pageCount: 2, name: "first.pdf")
        let secondPDF = try makePDFFile(pageCount: 3, name: "second.pdf")
        let outputURL = workDirectory.appendingPathComponent("merged.pdf")

        let resultURL = try await sut.mergePDFs(inputURLs: [firstPDF, secondPDF], outputURL: outputURL)

        let mergedDocument = try XCTUnwrap(PDFDocument(url: resultURL))
        XCTAssertEqual(mergedDocument.pageCount, 5)
    }

    func testMergePDFsThrowsWhenInputEmpty() async {
        let outputURL = workDirectory.appendingPathComponent("merged.pdf")

        await assertThrowsAsync(try await sut.mergePDFs(inputURLs: [], outputURL: outputURL)) { error in
            guard case PDFServiceError.emptyDocumentSet = error else {
                XCTFail("Expected emptyDocumentSet, got \(error)")
                return
            }
        }
    }

    // MARK: - createPDF

    func testCreatePDFFromImagesProducesOnePagePerImage() async throws {
        let firstImage = try makeImageFile(name: "first.jpg", size: CGSize(width: 100, height: 140), color: .red)
        let secondImage = try makeImageFile(name: "second.jpg", size: CGSize(width: 100, height: 140), color: .blue)
        let outputURL = workDirectory.appendingPathComponent("images.pdf")

        let resultURL = try await sut.createPDF(fromImages: [firstImage, secondImage], outputURL: outputURL)

        let document = try XCTUnwrap(PDFDocument(url: resultURL))
        XCTAssertEqual(document.pageCount, 2)
    }

    func testCreatePDFThrowsForUnsupportedImageFormat() async {
        let invalidFile = workDirectory.appendingPathComponent("not-an-image.jpg")
        try? Data("not an image".utf8).write(to: invalidFile)
        let outputURL = workDirectory.appendingPathComponent("images.pdf")

        await assertThrowsAsync(
            try await sut.createPDF(fromImages: [invalidFile], outputURL: outputURL)
        ) { error in
            guard case PDFServiceError.unsupportedImageFormat = error else {
                XCTFail("Expected unsupportedImageFormat, got \(error)")
                return
            }
        }
    }

    // MARK: - compressPDF

    func testCompressPDFProducesReadableOutputWithSamePageCount() async throws {
        let sourcePDF = try makePDFFile(pageCount: 2, name: "source.pdf")
        let outputURL = workDirectory.appendingPathComponent("compressed.pdf")

        let resultURL = try await sut.compressPDF(inputURL: sourcePDF, outputURL: outputURL, quality: .low)

        let compressedDocument = try XCTUnwrap(PDFDocument(url: resultURL))
        XCTAssertEqual(compressedDocument.pageCount, 2)
    }

    func testCompressPDFThrowsWhenSourceHasNoPages() async {
        let sourceURL = workDirectory.appendingPathComponent("empty.pdf")
        try? Data().write(to: sourceURL)
        let outputURL = workDirectory.appendingPathComponent("compressed.pdf")

        await assertThrowsAsync(
            try await sut.compressPDF(inputURL: sourceURL, outputURL: outputURL, quality: .medium)
        ) { error in
            guard case PDFServiceError.compressionFailed = error else {
                XCTFail("Expected compressionFailed, got \(error)")
                return
            }
        }
    }

    // MARK: - generateEditedPDF / extractPages

    func testGenerateEditedPDFReordersAndRotatesPages() async throws {
        let sourcePDF = try makePDFFile(pageCount: 3, name: "source.pdf")
        let outputURL = workDirectory.appendingPathComponent("edited.pdf")
        let pageEdits = [
            PDFPageEdit(sourcePageIndex: 2, rotationDelta: 90),
            PDFPageEdit(sourcePageIndex: 0)
        ]

        let resultURL = try await sut.generateEditedPDF(inputURL: sourcePDF, pageEdits: pageEdits, outputURL: outputURL)

        let editedDocument = try XCTUnwrap(PDFDocument(url: resultURL))
        XCTAssertEqual(editedDocument.pageCount, 2)
        let firstPage = try XCTUnwrap(editedDocument.page(at: 0))
        XCTAssertEqual(firstPage.rotation, 90)
    }

    func testGenerateEditedPDFThrowsForOutOfRangeIndex() async {
        do {
            let sourcePDF = try makePDFFile(pageCount: 1, name: "source.pdf")
            let outputURL = workDirectory.appendingPathComponent("edited.pdf")

            await assertThrowsAsync(
                try await sut.generateEditedPDF(
                    inputURL: sourcePDF,
                    pageEdits: [PDFPageEdit(sourcePageIndex: 5)],
                    outputURL: outputURL
                )
            ) { error in
                guard case PDFServiceError.invalidInput = error else {
                    XCTFail("Expected invalidInput, got \(error)")
                    return
                }
            }
        } catch {
            XCTFail("Failed to prepare fixture: \(error)")
        }
    }

    func testExtractPagesKeepsOnlyRequestedIndices() async throws {
        let sourcePDF = try makePDFFile(pageCount: 4, name: "source.pdf")
        let outputURL = workDirectory.appendingPathComponent("extracted.pdf")

        let resultURL = try await sut.extractPages(inputURL: sourcePDF, pageIndices: [1, 3], outputURL: outputURL)

        let extractedDocument = try XCTUnwrap(PDFDocument(url: resultURL))
        XCTAssertEqual(extractedDocument.pageCount, 2)
    }

    // MARK: - reorderPages / rotatePage / deletePages

    func testReorderPagesFiltersOutOfRangeIndices() throws {
        let document = try makePDFDocument(pageCount: 3)

        let reordered = sut.reorderPages(in: document, to: [2, 99, 0])

        XCTAssertEqual(reordered.pageCount, 2)
    }

    func testRotatePageNormalizesNegativeDegrees() throws {
        let document = try makePDFDocument(pageCount: 1)
        let page = try XCTUnwrap(document.page(at: 0))

        sut.rotatePage(page, byDegrees: -90)

        XCTAssertEqual(page.rotation, 270)
    }

    func testDeletePagesRemovesSpecifiedIndices() throws {
        let document = try makePDFDocument(pageCount: 3)

        sut.deletePages(from: document, at: IndexSet([0, 2]))

        XCTAssertEqual(document.pageCount, 1)
    }

    // MARK: - exportAsImages

    func testExportAsImagesReturnsOneImagePerPage() async throws {
        let sourcePDF = try makePDFFile(pageCount: 3, name: "source.pdf")

        let images = try await sut.exportAsImages(inputURL: sourcePDF)

        XCTAssertEqual(images.count, 3)
    }

    func testExportAsImagesThrowsForInvalidInput() async {
        let invalidURL = workDirectory.appendingPathComponent("missing.pdf")

        await assertThrowsAsync(
            try await sut.exportAsImages(inputURL: invalidURL)
        ) { error in
            guard case PDFServiceError.invalidInput = error else {
                XCTFail("Expected invalidInput, got \(error)")
                return
            }
        }
    }

    // MARK: - splitPDF

    func testSplitPDFCreatesOneFilePerRange() async throws {
        let sourcePDF = try makePDFFile(pageCount: 5, name: "source.pdf")
        let outputDirectory = workDirectory.appendingPathComponent("split", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let resultURLs = try await sut.splitPDF(
            inputURL: sourcePDF,
            pageRanges: [1...2, 3...5],
            outputDirectory: outputDirectory
        )

        XCTAssertEqual(resultURLs.count, 2)
        let firstDocument = try XCTUnwrap(PDFDocument(url: resultURLs[0]))
        let secondDocument = try XCTUnwrap(PDFDocument(url: resultURLs[1]))
        XCTAssertEqual(firstDocument.pageCount, 2)
        XCTAssertEqual(secondDocument.pageCount, 3)
    }

    func testSplitPDFThrowsForOutOfRangePages() async throws {
        let sourcePDF = try makePDFFile(pageCount: 2, name: "source.pdf")
        let outputDirectory = workDirectory.appendingPathComponent("split", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        await assertThrowsAsync(
            try await sut.splitPDF(inputURL: sourcePDF, pageRanges: [1...5], outputDirectory: outputDirectory)
        ) { error in
            guard case PDFServiceError.invalidPageRange = error else {
                XCTFail("Expected invalidPageRange, got \(error)")
                return
            }
        }
    }

    // MARK: - protectPDF / unlockPDF

    func testProtectPDFThenUnlockPDFRoundTrips() async throws {
        let sourcePDF = try makePDFFile(pageCount: 2, name: "source.pdf")
        let protectedURL = workDirectory.appendingPathComponent("protected.pdf")
        let unlockedURL = workDirectory.appendingPathComponent("unlocked.pdf")

        let protectedResultURL = try await sut.protectPDF(
            inputURL: sourcePDF,
            outputURL: protectedURL,
            password: "s3cret"
        )
        let protectedDocument = try XCTUnwrap(PDFDocument(url: protectedResultURL))
        XCTAssertTrue(protectedDocument.isEncrypted)
        XCTAssertTrue(protectedDocument.isLocked)

        let unlockedResultURL = try await sut.unlockPDF(
            inputURL: protectedResultURL,
            outputURL: unlockedURL,
            password: "s3cret"
        )
        let unlockedDocument = try XCTUnwrap(PDFDocument(url: unlockedResultURL))
        XCTAssertFalse(unlockedDocument.isLocked)
        XCTAssertEqual(unlockedDocument.pageCount, 2)
    }

    func testProtectPDFThrowsForEmptyPassword() async {
        do {
            let sourcePDF = try makePDFFile(pageCount: 1, name: "source.pdf")
            let outputURL = workDirectory.appendingPathComponent("protected.pdf")

            await assertThrowsAsync(
                try await sut.protectPDF(inputURL: sourcePDF, outputURL: outputURL, password: "")
            ) { error in
                guard case PDFServiceError.invalidInput = error else {
                    XCTFail("Expected invalidInput, got \(error)")
                    return
                }
            }
        } catch {
            XCTFail("Failed to prepare fixture: \(error)")
        }
    }

    func testUnlockPDFThrowsForIncorrectPassword() async throws {
        let sourcePDF = try makePDFFile(pageCount: 1, name: "source.pdf")
        let protectedURL = workDirectory.appendingPathComponent("protected.pdf")
        _ = try await sut.protectPDF(inputURL: sourcePDF, outputURL: protectedURL, password: "correct-password")
        let outputURL = workDirectory.appendingPathComponent("unlocked.pdf")

        await assertThrowsAsync(
            try await sut.unlockPDF(inputURL: protectedURL, outputURL: outputURL, password: "wrong-password")
        ) { error in
            guard case PDFServiceError.incorrectPassword = error else {
                XCTFail("Expected incorrectPassword, got \(error)")
                return
            }
        }
    }

    // MARK: - addWatermark

    func testAddWatermarkPreservesPageCount() async throws {
        let sourcePDF = try makePDFFile(pageCount: 3, name: "source.pdf")
        let outputURL = workDirectory.appendingPathComponent("watermarked.pdf")

        let resultURL = try await sut.addWatermark(inputURL: sourcePDF, text: "CONFIDENTIAL", outputURL: outputURL)

        let watermarkedDocument = try XCTUnwrap(PDFDocument(url: resultURL))
        XCTAssertEqual(watermarkedDocument.pageCount, 3)
    }

    func testAddWatermarkThrowsForEmptyText() async {
        do {
            let sourcePDF = try makePDFFile(pageCount: 1, name: "source.pdf")
            let outputURL = workDirectory.appendingPathComponent("watermarked.pdf")

            await assertThrowsAsync(
                try await sut.addWatermark(inputURL: sourcePDF, text: "", outputURL: outputURL)
            ) { error in
                guard case PDFServiceError.invalidInput = error else {
                    XCTFail("Expected invalidInput, got \(error)")
                    return
                }
            }
        } catch {
            XCTFail("Failed to prepare fixture: \(error)")
        }
    }

    // MARK: - convertToOffice

    func testConvertToOfficeWritesOutputFile() async throws {
        let sourcePDF = try makePDFFile(pageCount: 1, name: "source.pdf")
        let outputURL = workDirectory.appendingPathComponent("converted.docx")

        let resultURL = try await sut.convertToOffice(inputURL: sourcePDF, format: .word, outputURL: outputURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: resultURL.path))
    }

    func testConvertToOfficeThrowsWhenSourceHasNoPages() async {
        let sourceURL = workDirectory.appendingPathComponent("empty.pdf")
        try? Data().write(to: sourceURL)
        let outputURL = workDirectory.appendingPathComponent("converted.xlsx")

        await assertThrowsAsync(
            try await sut.convertToOffice(inputURL: sourceURL, format: .excel, outputURL: outputURL)
        ) { error in
            guard case PDFServiceError.invalidInput = error else {
                XCTFail("Expected invalidInput, got \(error)")
                return
            }
        }
    }

    func testConvertToOfficeWritesValidOOXMLPackage() async throws {
        let sourcePDF = try makePDFFile(pageCount: 1, name: "source.pdf")

        for format in OfficeFormat.allCases {
            let outputURL = workDirectory.appendingPathComponent("converted-\(format.rawValue).\(format.fileExtension)")

            let resultURL = try await sut.convertToOffice(inputURL: sourcePDF, format: format, outputURL: outputURL)

            let data = try Data(contentsOf: resultURL)
            // OOXML (docx/xlsx/pptx) はZIPコンテナのため、先頭にZIPのローカルファイルヘッダー署名("PK\x03\x04")を持つ。
            XCTAssertEqual(data.prefix(4), Data([0x50, 0x4B, 0x03, 0x04]))
        }
    }

    func testConvertToOfficeExtractsSeparateColumnsForExcel() async throws {
        let sourcePDF = try makeTwoColumnPDFFile(name: "table.pdf")
        let outputURL = workDirectory.appendingPathComponent("converted-table.xlsx")

        let resultURL = try await sut.convertToOffice(inputURL: sourcePDF, format: .excel, outputURL: outputURL)

        let xlsxData = try Data(contentsOf: resultURL)
        let sheets = try OfficeSpreadsheetReader.readSheets(from: xlsxData)
        let rows = try XCTUnwrap(sheets.first?.rows)
        let rowWithTwoCells = try XCTUnwrap(rows.first { $0.count >= 2 })
        XCTAssertEqual(rowWithTwoCells[0], "Left")
        XCTAssertEqual(rowWithTwoCells[1], "Right")
    }

    func testConvertToOfficeEmbedsPageImageForPowerPoint() async throws {
        let sourcePDF = try makePDFFile(pageCount: 2, name: "source.pdf")
        let outputURL = workDirectory.appendingPathComponent("converted.pptx")

        let resultURL = try await sut.convertToOffice(inputURL: sourcePDF, format: .powerPoint, outputURL: outputURL)

        let pptxData = try Data(contentsOf: resultURL)
        let (_, slides) = try OfficePresentationReader.readSlides(from: pptxData)
        XCTAssertEqual(slides.count, 2)
        for slide in slides {
            guard case .image = slide.elements.first else {
                XCTFail("Expected an image element per slide")
                return
            }
        }
    }

    func testConvertToOfficeThrowsOfficeConversionFailedForInvalidOutputPath() async throws {
        let sourcePDF = try makePDFFile(pageCount: 1, name: "source.pdf")
        let outputURL = workDirectory
            .appendingPathComponent("missing-directory", isDirectory: true)
            .appendingPathComponent("converted.docx")

        await assertThrowsAsync(
            try await sut.convertToOffice(inputURL: sourcePDF, format: .word, outputURL: outputURL)
        ) { error in
            guard case PDFServiceError.officeConversionFailed = error else {
                XCTFail("Expected officeConversionFailed, got \(error)")
                return
            }
        }
    }

    func testConvertToOfficeThrowsPasswordProtectedFileForLockedPDF() async throws {
        let sourcePDF = try makePDFFile(pageCount: 1, name: "source.pdf")
        let protectedURL = workDirectory.appendingPathComponent("protected.pdf")
        _ = try await sut.protectPDF(inputURL: sourcePDF, outputURL: protectedURL, password: "s3cret")
        let outputURL = workDirectory.appendingPathComponent("converted.docx")

        await assertThrowsAsync(
            try await sut.convertToOffice(inputURL: protectedURL, format: .word, outputURL: outputURL)
        ) { error in
            guard case PDFServiceError.passwordProtectedFile = error else {
                XCTFail("Expected passwordProtectedFile, got \(error)")
                return
            }
        }
    }

    func testConvertToOfficeThrowsFileTooLargeForOversizedInput() async throws {
        let oversizedURL = try makeOversizedFile(name: "huge.pdf")
        let outputURL = workDirectory.appendingPathComponent("converted.docx")

        await assertThrowsAsync(
            try await sut.convertToOffice(inputURL: oversizedURL, format: .word, outputURL: outputURL)
        ) { error in
            guard case PDFServiceError.fileTooLarge = error else {
                XCTFail("Expected fileTooLarge, got \(error)")
                return
            }
        }
    }

    func testConvertToOfficeThrowsInvalidInputForCorruptedPDFData() async {
        let corruptedURL = workDirectory.appendingPathComponent("corrupted.pdf")
        try? Data("this is not a valid PDF".utf8).write(to: corruptedURL)
        let outputURL = workDirectory.appendingPathComponent("converted.docx")

        await assertThrowsAsync(
            try await sut.convertToOffice(inputURL: corruptedURL, format: .word, outputURL: outputURL)
        ) { error in
            guard case PDFServiceError.invalidInput = error else {
                XCTFail("Expected invalidInput, got \(error)")
                return
            }
        }
    }

    func testConvertToOfficeReportsProgressUpToCompletion() async throws {
        let sourcePDF = try makePDFFile(pageCount: 3, name: "source.pdf")
        let outputURL = workDirectory.appendingPathComponent("converted.docx")
        let recorder = ProgressRecorder()

        _ = try await sut.convertToOffice(inputURL: sourcePDF, format: .word, outputURL: outputURL) { value in
            recorder.record(value)
        }

        let values = recorder.values
        XCTAssertEqual(values.count, 3)
        XCTAssertEqual(values, values.sorted())
        XCTAssertEqual(values.last, 1.0)
    }

    // MARK: - convertOfficeToPDF

    func testConvertOfficeToPDFConvertsWordDocument() async throws {
        let docxData = OfficeDocumentBuilder.makeDocx(pageTexts: ["Hello PDF One", "Second paragraph"])
        let sourceDocx = workDirectory.appendingPathComponent("source.docx")
        try docxData.write(to: sourceDocx)
        let outputURL = workDirectory.appendingPathComponent("converted.pdf")

        let resultURL = try await sut.convertOfficeToPDF(inputURL: sourceDocx, format: .word, outputURL: outputURL)

        let document = try XCTUnwrap(PDFDocument(url: resultURL))
        XCTAssertGreaterThan(document.pageCount, 0)
        let extractedText = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined()
        XCTAssertTrue(extractedText.contains("Hello PDF One"))
    }

    func testConvertOfficeToPDFConvertsExcelWorkbook() async throws {
        let xlsxData = OfficeDocumentBuilder.makeXlsx(sheets: [[["Header1", "Header2"], ["Value1", "Value2"]]])
        let sourceXlsx = workDirectory.appendingPathComponent("source.xlsx")
        try xlsxData.write(to: sourceXlsx)
        let outputURL = workDirectory.appendingPathComponent("converted-excel.pdf")

        let resultURL = try await sut.convertOfficeToPDF(inputURL: sourceXlsx, format: .excel, outputURL: outputURL)

        let document = try XCTUnwrap(PDFDocument(url: resultURL))
        XCTAssertGreaterThan(document.pageCount, 0)
        let extractedText = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined()
        XCTAssertTrue(extractedText.contains("Value1"))
    }

    func testConvertOfficeToPDFConvertsPowerPointPresentation() async throws {
        let pptxData = OfficeDocumentBuilder.makePptx(slides: [.text("Hello Slide")])
        let sourcePptx = workDirectory.appendingPathComponent("source.pptx")
        try pptxData.write(to: sourcePptx)
        let outputURL = workDirectory.appendingPathComponent("converted-ppt.pdf")

        let resultURL = try await sut.convertOfficeToPDF(inputURL: sourcePptx, format: .powerPoint, outputURL: outputURL)

        let document = try XCTUnwrap(PDFDocument(url: resultURL))
        XCTAssertGreaterThan(document.pageCount, 0)
        let extractedText = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined()
        XCTAssertTrue(extractedText.contains("Hello Slide"))
    }

    func testConvertOfficeToPDFThrowsFileTooLargeForOversizedInput() async throws {
        let oversizedURL = try makeOversizedFile(name: "huge.docx")
        let outputURL = workDirectory.appendingPathComponent("converted.pdf")

        await assertThrowsAsync(
            try await sut.convertOfficeToPDF(inputURL: oversizedURL, format: .word, outputURL: outputURL)
        ) { error in
            guard case PDFServiceError.fileTooLarge = error else {
                XCTFail("Expected fileTooLarge, got \(error)")
                return
            }
        }
    }

    func testConvertOfficeToPDFThrowsPasswordProtectedFileForEncryptedContainer() async throws {
        let encryptedURL = workDirectory.appendingPathComponent("protected.docx")
        // MS-OFFCRYPTOで暗号化されたOffice文書は、通常のZIPではなくOLE構造化ストレージ(CFBF)でラップされ、
        // このシグネチャで始まる。ZIP解析を試みる前に検出できることを確認する。
        let cfbSignature = Data([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1])
        try (cfbSignature + Data(repeating: 0, count: 64)).write(to: encryptedURL)
        let outputURL = workDirectory.appendingPathComponent("converted.pdf")

        await assertThrowsAsync(
            try await sut.convertOfficeToPDF(inputURL: encryptedURL, format: .word, outputURL: outputURL)
        ) { error in
            guard case PDFServiceError.passwordProtectedFile = error else {
                XCTFail("Expected passwordProtectedFile, got \(error)")
                return
            }
        }
    }

    func testConvertOfficeToPDFThrowsOfficeConversionFailedForCorruptedZip() async throws {
        let corruptedURL = workDirectory.appendingPathComponent("corrupted.docx")
        try Data("this is not a valid zip/office package".utf8).write(to: corruptedURL)
        let outputURL = workDirectory.appendingPathComponent("converted.pdf")

        await assertThrowsAsync(
            try await sut.convertOfficeToPDF(inputURL: corruptedURL, format: .word, outputURL: outputURL)
        ) { error in
            guard case PDFServiceError.officeConversionFailed = error else {
                XCTFail("Expected officeConversionFailed, got \(error)")
                return
            }
        }
    }

    func testConvertOfficeToPDFReportsProgressUpToCompletion() async throws {
        let pptxData = OfficeDocumentBuilder.makePptx(slides: [.text("A"), .text("B"), .text("C")])
        let sourcePptx = workDirectory.appendingPathComponent("source.pptx")
        try pptxData.write(to: sourcePptx)
        let outputURL = workDirectory.appendingPathComponent("converted.pdf")
        let recorder = ProgressRecorder()

        _ = try await sut.convertOfficeToPDF(inputURL: sourcePptx, format: .powerPoint, outputURL: outputURL) { value in
            recorder.record(value)
        }

        let values = recorder.values
        XCTAssertEqual(values.count, 3)
        XCTAssertEqual(values, values.sorted())
        XCTAssertEqual(values.last, 1.0)
    }

    // MARK: - Helpers

    private func makePDFDocument(pageCount: Int) throws -> PDFDocument {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 100, height: 140))
        let data = renderer.pdfData { context in
            for _ in 0..<pageCount {
                context.beginPage()
            }
        }
        return try XCTUnwrap(PDFDocument(data: data))
    }

    private func makePDFFile(pageCount: Int, name: String) throws -> URL {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 100, height: 140))
        let data = renderer.pdfData { context in
            for _ in 0..<pageCount {
                context.beginPage()
            }
        }
        let url = workDirectory.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    /// `PDFService.maxInputFileSizeBytes`を超えるサイズのスパースファイルを作成する。
    /// 実データを書き込まず`truncate`でサイズだけを設定するため、実ディスク消費・実行時間を抑えられる。
    private func makeOversizedFile(name: String) throws -> URL {
        let url = workDirectory.appendingPathComponent(name)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: UInt64(PDFService.maxInputFileSizeBytes) + 1)
        try handle.close()
        return url
    }

    /// 同一行の離れたX座標に2つの文字列を描画したPDFを作成する。表抽出ヒューリスティクスの列分割テスト用。
    private func makeTwoColumnPDFFile(name: String) throws -> URL {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 400, height: 100))
        let data = renderer.pdfData { context in
            context.beginPage()
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 14)]
            ("Left" as NSString).draw(at: CGPoint(x: 20, y: 40), withAttributes: attributes)
            ("Right" as NSString).draw(at: CGPoint(x: 250, y: 40), withAttributes: attributes)
        }
        let url = workDirectory.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    private func makeImageFile(name: String, size: CGSize, color: UIColor) throws -> URL {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        let data = try XCTUnwrap(image.jpegData(compressionQuality: 0.9))
        let url = workDirectory.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }
}

/// `onProgress`コールバックはactor内から任意のタイミングで呼ばれるため、テスト側での値収集をロックで保護する。
private final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedValues: [Double] = []

    var values: [Double] {
        lock.lock()
        defer { lock.unlock() }
        return recordedValues
    }

    func record(_ value: Double) {
        lock.lock()
        defer { lock.unlock() }
        recordedValues.append(value)
    }
}

/// XCTest には async throws 版の `XCTAssertThrowsError` が無いため用意するヘルパー。
private func assertThrowsAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ errorHandler: (Error) -> Void
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error to be thrown", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
