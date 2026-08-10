import Foundation
import PDFKit
import UIKit

/// グリッド上の1ページ分の編集状態（元PDF内での位置・追加回転角・抽出用の選択状態・サムネイル）を保持する。
struct PDFPageEditItem: Identifiable {
    let id = UUID()
    let originalIndex: Int
    var rotation: Int = 0
    var isSelected: Bool = false
    var thumbnail: UIImage?
}

@Observable
@MainActor
final class PageEditViewModel {

    var sourceURL: URL? {
        didSet {
            outputURL = nil
            guard let sourceURL else {
                pageItems = []
                return
            }
            loadPages(from: sourceURL)
        }
    }

    var pageItems: [PDFPageEditItem] = []
    var isProcessing: Bool = false
    var outputURL: URL?
    var errorMessage: String?

    private let pdfService: PDFServiceProtocol
    private static let thumbnailSize = CGSize(width: 200, height: 280)

    init(pdfService: PDFServiceProtocol = PDFService()) {
        self.pdfService = pdfService
    }

    var hasSelection: Bool {
        pageItems.contains { $0.isSelected }
    }

    func rotatePage(id: PDFPageEditItem.ID) {
        guard let index = pageItems.firstIndex(where: { $0.id == id }) else { return }
        pageItems[index].rotation = (pageItems[index].rotation + 90) % 360
    }

    func deletePage(id: PDFPageEditItem.ID) {
        pageItems.removeAll { $0.id == id }
    }

    func toggleSelection(id: PDFPageEditItem.ID) {
        guard let index = pageItems.firstIndex(where: { $0.id == id }) else { return }
        pageItems[index].isSelected.toggle()
    }

    func saveEditedPDF() async {
        guard let sourceURL else {
            errorMessage = "編集対象のPDFファイルを選択してください。"
            return
        }
        guard !pageItems.isEmpty else {
            errorMessage = "PDFには少なくとも1ページ必要です。"
            return
        }

        isProcessing = true
        errorMessage = nil
        outputURL = nil

        let pageEdits = pageItems.map {
            PDFPageEdit(sourcePageIndex: $0.originalIndex, rotationDelta: $0.rotation)
        }

        do {
            let destinationURL = try Self.makeTemporaryPDFURL()
            outputURL = try await pdfService.generateEditedPDF(
                inputURL: sourceURL,
                pageEdits: pageEdits,
                outputURL: destinationURL
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    func extractSelectedPages() async {
        guard let sourceURL else {
            errorMessage = "編集対象のPDFファイルを選択してください。"
            return
        }

        let selectedIndices = pageItems.filter(\.isSelected).map(\.originalIndex)
        guard !selectedIndices.isEmpty else {
            errorMessage = "抽出するページを選択してください。"
            return
        }

        isProcessing = true
        errorMessage = nil
        outputURL = nil

        do {
            let destinationURL = try Self.makeTemporaryPDFURL()
            outputURL = try await pdfService.extractPages(
                inputURL: sourceURL,
                pageIndices: selectedIndices,
                outputURL: destinationURL
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    private func loadPages(from url: URL) {
        errorMessage = nil

        guard let document = PDFDocument(url: url), document.pageCount > 0 else {
            errorMessage = "PDFファイルを読み込めませんでした。"
            pageItems = []
            return
        }

        pageItems = (0..<document.pageCount).compactMap { index -> PDFPageEditItem? in
            guard let page = document.page(at: index) else { return nil }
            let thumbnail = page.thumbnail(of: Self.thumbnailSize, for: .mediaBox)
            return PDFPageEditItem(originalIndex: index, thumbnail: thumbnail)
        }
    }

    private static func makeTemporaryPDFURL() throws -> URL {
        try SavedFileStore.directory()
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
    }
}
