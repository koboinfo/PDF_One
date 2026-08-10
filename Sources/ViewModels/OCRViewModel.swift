import Foundation
import UIKit

@Observable
final class OCRViewModel {

    var selectedURL: URL? {
        didSet {
            extractedText = ""
            savedTextFileURL = nil
            errorMessage = nil
        }
    }

    var extractedText: String = ""
    var isProcessing: Bool = false
    var errorMessage: String?
    var savedTextFileURL: URL?

    private let ocrService: OCRServiceProtocol

    init(ocrService: OCRServiceProtocol = OCRService()) {
        self.ocrService = ocrService
    }

    var canExtract: Bool {
        selectedURL != nil
    }

    func extractText() async {
        guard let selectedURL else {
            errorMessage = "テキストを抽出するPDFファイルを選択してください。"
            return
        }

        isProcessing = true
        errorMessage = nil
        extractedText = ""
        savedTextFileURL = nil

        do {
            let text = try await ocrService.extractText(from: selectedURL)
            extractedText = text
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errorMessage = "テキストを検出できませんでした。"
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    func copyToClipboard() {
        UIPasteboard.general.string = extractedText
    }

    func saveAsTextFile() {
        guard !extractedText.isEmpty else { return }

        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("txt")

        do {
            try extractedText.write(to: destinationURL, atomically: true, encoding: .utf8)
            savedTextFileURL = destinationURL
        } catch {
            errorMessage = "テキストファイルの保存に失敗しました。"
        }
    }
}
