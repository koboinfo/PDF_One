import SwiftUI
import UniformTypeIdentifiers

struct ProtectPDFView: View {
    @State private var viewModel = ProtectPDFViewModel()
    @State private var isShowingImporter = false

    var body: some View {
        BaseToolView(
            title: "パスワード設定",
            helpText: "PDFにパスワードを設定して保護します。"
        ) {
            Group {
                if viewModel.selectedURL == nil {
                    emptyStateView
                } else {
                    protectForm
                }
            }
        }
        .overlay {
            if viewModel.isProcessing {
                NeumorphicProcessingCard(message: "処理中…")
            }
        }
        .fileImporter(isPresented: $isShowingImporter, allowedContentTypes: [.pdf]) { result in
            switch result {
            case .success(let url):
                viewModel.selectedURL = url
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .alert(
            "エラー",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var emptyStateView: some View {
        EmptyStateView(
            systemImage: "lock.doc",
            title: "パスワードを設定したいPDFファイルを選択してください",
            actionTitle: "PDFを選択"
        ) {
            isShowingImporter = true
        }
    }

    private var protectForm: some View {
        Form {
            Section("選択中のファイル") {
                Label(viewModel.selectedURL?.lastPathComponent ?? "", systemImage: "doc.text")
                    .lineLimit(1)

                Button("別のファイルを選択") {
                    isShowingImporter = true
                }
            }

            Section("パスワード") {
                SecureField("パスワード", text: $viewModel.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                SecureField("パスワード（確認用）", text: $viewModel.confirmPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }

            if let outputURL = viewModel.outputURL {
                Section("保護結果") {
                    ShareLink(item: outputURL) {
                        Label("共有する", systemImage: "square.and.arrow.up")
                    }
                }
            }

            Section {
                PrimaryButton(
                    title: "パスワードを設定する",
                    systemImage: "lock.doc.fill",
                    isProcessing: viewModel.isProcessing,
                    isDisabled: !viewModel.canProtect
                ) {
                    Task { await viewModel.protectPDF() }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

#Preview {
    ProtectPDFView()
}
