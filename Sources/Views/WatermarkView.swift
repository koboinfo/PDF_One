import SwiftUI
import UniformTypeIdentifiers

struct WatermarkView: View {
    @State private var viewModel = WatermarkViewModel()
    @State private var isShowingImporter = false
    @Environment(SubscriptionManager.self) private var subscriptionManager

    var body: some View {
        Group {
            if subscriptionManager.isProUser {
                toolContent
            } else {
                PaywallContentView()
            }
        }
    }

    private var toolContent: some View {
        BaseToolView(
            title: String(localized: "透かし"),
            helpText: String(localized: "PDFの各ページに透かしテキストを追加します。")
        ) {
            Group {
                if viewModel.selectedURL == nil {
                    emptyStateView
                } else {
                    watermarkForm
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
            systemImage: "drop",
            title: String(localized: "透かしを追加したいPDFファイルを選択してください"),
            actionTitle: String(localized: "PDFを選択")
        ) {
            isShowingImporter = true
        }
    }

    private var watermarkForm: some View {
        Form {
            Section(String(localized: "選択中のファイル")) {
                Label(viewModel.selectedURL?.lastPathComponent ?? "", systemImage: "doc.text")
                    .lineLimit(1)

                Button(String(localized: "別のファイルを選択")) {
                    isShowingImporter = true
                }
            }

            Section(String(localized: "透かしテキスト")) {
                TextField(String(localized: "例：CONFIDENTIAL"), text: $viewModel.watermarkText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }

            if let outputURL = viewModel.outputURL {
                Section(String(localized: "透かし結果")) {
                    ShareLink(item: outputURL) {
                        Label(String(localized: "共有する"), systemImage: "square.and.arrow.up")
                    }
                }
            }

            Section {
                PrimaryButton(
                    title: String(localized: "透かしを追加する"),
                    systemImage: "drop.fill",
                    isProcessing: viewModel.isProcessing,
                    isDisabled: !viewModel.canAddWatermark
                ) {
                    Task { await viewModel.addWatermark() }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

#Preview {
    WatermarkView()
        .environment(SubscriptionManager())
}
