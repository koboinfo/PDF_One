import SwiftUI
import UniformTypeIdentifiers

struct ProtectPDFView: View {
    @State private var viewModel = ProtectPDFViewModel()
    @State private var isShowingImporter = false

    var body: some View {
        BaseToolView(
            title: String(localized: "パスワード設定"),
            helpText: String(localized: "PDFにパスワードを設定して保護します。")
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
                NeumorphicProcessingCard(message: String(localized: "処理中…"))
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
            String(localized: "エラー"),
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
            title: String(localized: "パスワードを設定したいPDFファイルを選択してください"),
            actionTitle: String(localized: "PDFを選択")
        ) {
            isShowingImporter = true
        }
    }

    private var protectForm: some View {
        Form {
            Section(String(localized: "選択中のファイル")) {
                Label(viewModel.selectedURL?.lastPathComponent ?? "", systemImage: "doc.text")
                    .lineLimit(1)

                Button(String(localized: "別のファイルを選択")) {
                    isShowingImporter = true
                }
            }

            Section(String(localized: "パスワード")) {
                SecureField(String(localized: "パスワード"), text: $viewModel.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                SecureField(String(localized: "パスワード（確認用）"), text: $viewModel.confirmPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }

            if let outputURL = viewModel.outputURL {
                Section(String(localized: "保護結果")) {
                    ShareLink(item: outputURL) {
                        Label(String(localized: "共有する"), systemImage: "square.and.arrow.up")
                    }
                }
            }

            Section {
                PrimaryButton(
                    title: String(localized: "パスワードを設定する"),
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
