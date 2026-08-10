import Foundation

@Observable
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
            errorMessage = "保護するPDFファイルを選択してください。"
            return
        }
        guard !password.isEmpty else {
            errorMessage = "パスワードを入力してください。"
            return
        }
        guard password == confirmPassword else {
            errorMessage = "パスワードが一致しません。"
            return
        }

        isProcessing = true
        errorMessage = nil

        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")

        do {
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
