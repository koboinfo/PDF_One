import Foundation

@Observable
@MainActor
final class CompressViewModel {

    var selectedURL: URL? {
        didSet { outputURL = nil }
    }
    var compressionQuality: PDFCompressionQuality = .medium
    var isProcessing: Bool = false
    var outputURL: URL?
    var errorMessage: String?

    private let pdfService: PDFServiceProtocol

    init(pdfService: PDFServiceProtocol = PDFService()) {
        self.pdfService = pdfService
    }

    var originalFileSizeBytes: Int64? {
        selectedURL.flatMap(Self.fileSize(at:))
    }

    var compressedFileSizeBytes: Int64? {
        outputURL.flatMap(Self.fileSize(at:))
    }

    var reductionPercentText: String? {
        guard let originalFileSizeBytes, let compressedFileSizeBytes, originalFileSizeBytes > 0 else {
            return nil
        }
        let reduction = 1 - Double(compressedFileSizeBytes) / Double(originalFileSizeBytes)
        let percentText = max(0, reduction).formatted(.percent.precision(.fractionLength(0)))
        return String(localized: "\(percentText)削減")
    }

    func compressPDF() async {
        guard let selectedURL else {
            errorMessage = String(localized: "圧縮するPDFファイルを選択してください。")
            return
        }

        isProcessing = true
        errorMessage = nil
        AdMobInterstitialManager.shared.preloadAd()

        do {
            let destinationURL = try SavedFileStore.directory()
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("pdf")

            let compressedURL = try await pdfService.compressPDF(
                inputURL: selectedURL,
                outputURL: destinationURL,
                quality: compressionQuality
            )
            outputURL = compressedURL
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    static func formattedFileSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private static func fileSize(at url: URL) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return nil
        }
        return attributes[.size] as? Int64
    }
}

extension PDFCompressionQuality {
    static let selectableQualities: [PDFCompressionQuality] = [.low, .medium, .high]

    var label: String {
        switch self {
        case .low: return String(localized: "低（サイズ優先）")
        case .medium: return String(localized: "中")
        case .high: return String(localized: "高（画質優先）")
        case .custom: return String(localized: "カスタム")
        }
    }
}
