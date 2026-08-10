import Foundation

@Observable
@MainActor
final class ImageToPDFViewModel {

    /// ローカル選択画像・Cloudinary等のリモートURL画像を区別なく保持する。
    var images: [AppImage] = []
    var isProcessing: Bool = false
    var outputURL: URL?
    var errorMessage: String?

    private let pdfService: PDFServiceProtocol
    private let imageResolver: ImageSourceResolving

    init(
        pdfService: PDFServiceProtocol = PDFService(),
        imageResolver: ImageSourceResolving = ImageSourceResolver()
    ) {
        self.pdfService = pdfService
        self.imageResolver = imageResolver
    }

    func appendLocalImages(urls: [URL]) {
        images.append(contentsOf: urls.map(AppImage.local))
    }

    func appendRemoteImages(urls: [URL]) {
        images.append(contentsOf: urls.map(AppImage.remote))
    }

    /// 変換結果を破棄し、新しい画像選択からやり直せる状態に戻す。
    func reset() {
        images = []
        outputURL = nil
        errorMessage = nil
    }

    var outputFileSizeText: String? {
        guard let outputURL,
              let size = try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64 else {
            return nil
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    func createPDF() async {
        guard !images.isEmpty else {
            errorMessage = "変換する画像を選択してください。"
            return
        }

        isProcessing = true
        errorMessage = nil

        do {
            var localImageURLs: [URL] = []
            for image in images {
                localImageURLs.append(try await imageResolver.resolveLocalURL(for: image))
            }

            let destinationURL = try SavedFileStore.directory()
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("pdf")

            outputURL = try await pdfService.createPDF(
                fromImages: localImageURLs,
                outputURL: destinationURL
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }
}
