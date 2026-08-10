import Foundation
import PDFKit
import UIKit
import Vision

enum OCRServiceError: Error {
    case invalidInput
    case recognitionFailed
    case passwordProtectedFile
    case fileTooLarge(maxBytes: Int64)
}

extension OCRServiceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "PDFファイルを読み込めませんでした。ファイルが破損しているか、対応していない形式の可能性があります。"
        case .recognitionFailed:
            return "文字認識に失敗しました。"
        case .passwordProtectedFile:
            return "パスワード保護されたPDFです。「パスワード設定」機能で保護を解除してからお試しください。"
        case .fileTooLarge(let maxBytes):
            let maxMB = maxBytes / 1_000_000
            return "ファイルサイズが大きすぎます（上限\(maxMB)MB）。ファイルを分割するか圧縮してからお試しください。"
        }
    }
}

protocol OCRServiceProtocol {
    func extractText(from pdfURL: URL, onProgress: (@Sendable (Double) -> Void)?) async throws -> String
}

/// Visionによるページ画像の文字認識はCPU負荷が高いため、actorとしてメインスレッド外で実行しUIフリーズを防ぐ。
actor OCRService: OCRServiceProtocol {

    static let maxInputFileSizeBytes: Int64 = 100_000_000

    func extractText(from pdfURL: URL, onProgress: (@Sendable (Double) -> Void)? = nil) async throws -> String {
        if let fileSize = try? FileManager.default.attributesOfItem(atPath: pdfURL.path)[.size] as? Int64,
           fileSize > Self.maxInputFileSizeBytes {
            throw OCRServiceError.fileTooLarge(maxBytes: Self.maxInputFileSizeBytes)
        }

        guard let document = PDFDocument(url: pdfURL), document.pageCount > 0 else {
            throw OCRServiceError.invalidInput
        }

        guard !document.isLocked else {
            throw OCRServiceError.passwordProtectedFile
        }

        var recognizedPages: [String] = []

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex), let cgImage = renderPageImage(page)?.cgImage else {
                throw OCRServiceError.recognitionFailed
            }
            let pageText = try await recognizeText(in: cgImage)
            recognizedPages.append(pageText)
            onProgress?(Double(pageIndex + 1) / Double(document.pageCount))
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
