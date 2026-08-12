import Foundation

@Observable
@MainActor
final class ProtectPDFViewModel {

    var selectedURL: URL? {
        didSet { outputURL = nil }
    }
    var password: String = ""
    var confirmPassword: String = ""
    var isProcessing: Bool = false
    var outputURL: URL?
    var errorMessage: String?

    private let pdfService: PDFServiceProtocol

    init(pdfService: PDFServiceProtocol = PDFService()) {
        self.pdfService = pdfService
    }

    var canProtect: Bool {
        selectedURL != nil && !password.isEmpty && password == confirmPassword
    }

    func protectPDF() async {
        guard let selectedURL else {
            errorMessage = String(localized: "保護するPDFファイルを選択してください。")
            return
        }
        guard !password.isEmpty else {
            errorMessage = String(localized: "パスワードを入力してください。")
            return
        }
        guard password == confirmPassword else {
            errorMessage = String(localized: "パスワードが一致しません。")
            return
        }

        isProcessing = true
        errorMessage = nil

        do {
            let destinationURL = try SavedFileStore.directory()
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("pdf")

            outputURL = try await pdfService.protectPDF(
                inputURL: selectedURL,
                outputURL: destinationURL,
                password: password
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }
}
