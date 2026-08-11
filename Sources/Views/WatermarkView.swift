import SwiftUI
import UniformTypeIdentifiers

struct WatermarkView: View {
    @State private var viewModel = WatermarkViewModel()
    @State private var isShowingImporter = false
    @Environment(SubscriptionManager.self) private var subscriptionManager

    var body: some View {
        Group {
            if subscriptionManager.isSubscribed {
                toolContent
            } else {
                PaywallView()
            }
        }
    }

    private var toolContent: some View {
        BaseToolView(
            title: "透かし",
            helpText: "PDFの各ページに透かしテキストを追加します。"
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
            systemImage: "drop",
            title: "透かしを追加したいPDFファイルを選択してください",
            actionTitle: "PDFを選択"
        ) {
            isShowingImporter = true
        }
    }

    private var watermarkForm: some View {
        Form {
            Section("選択中のファイル") {
                Label(viewModel.selectedURL?.lastPathComponent ?? "", systemImage: "doc.text")
                    .lineLimit(1)

                Button("別のファイルを選択") {
                    isShowingImporter = true
                }
            }

            Section("透かしテキスト") {
                TextField("例：CONFIDENTIAL", text: $viewModel.watermarkText)
            }

            if let outputURL = viewModel.outputURL {
                Section("透かし結果") {
                    ShareLink(item: outputURL) {
                        Label("共有する", systemImage: "square.and.arrow.up")
                    }
                }
            }

            Section {
                PrimaryButton(
                    title: "透かしを追加する",
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
