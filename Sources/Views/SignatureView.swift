import SwiftUI
import UniformTypeIdentifiers

struct SignatureView: View {
    @State private var viewModel = SignatureViewModel()
    @State private var isShowingImporter = false
    @State private var isShowingDrawingSheet = false
    @State private var isShowingShareSheet = false
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
            title: String(localized: "PDFに署名"),
            helpText: String(localized: "手書きの署名を描いてPDFの好きな位置に配置できます。")
        ) {
            Group {
                if viewModel.sourceURL == nil {
                    emptyStateView
                } else {
                    signatureForm
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
                viewModel.sourceURL = url
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $isShowingDrawingSheet) {
            SignatureDrawingSheet { image in
                viewModel.signatureImage = image
            }
        }
        .sheet(isPresented: $isShowingShareSheet) {
            if let outputURL = viewModel.outputURL {
                ActivityView(activityItems: [outputURL])
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
            systemImage: "signature",
            title: String(localized: "署名したいPDFファイルを選択してください"),
            actionTitle: String(localized: "PDFを選択")
        ) {
            isShowingImporter = true
        }
    }

    private var signatureForm: some View {
        Form {
            Section(String(localized: "選択中のファイル")) {
                Label(viewModel.sourceURL?.lastPathComponent ?? "", systemImage: "doc.text")
                    .lineLimit(1)
                Button(String(localized: "別のファイルを選択")) { isShowingImporter = true }

                if viewModel.pageCount > 1 {
                    Picker(String(localized: "ページ"), selection: $viewModel.pageIndex) {
                        ForEach(0..<viewModel.pageCount, id: \.self) { index in
                            Text(String(localized: "ページ \(index + 1)")).tag(index)
                        }
                    }
                }
            }

            Section(String(localized: "署名")) {
                if let signatureImage = viewModel.signatureImage, let pageThumbnail = viewModel.pageThumbnail {
                    SignaturePlacementView(
                        pageThumbnail: pageThumbnail,
                        previewSize: CGSize(width: SignatureViewModel.previewWidth, height: viewModel.previewHeight),
                        signatureImage: signatureImage,
                        position: $viewModel.signaturePosition,
                        size: $viewModel.signatureSize
                    )
                    .frame(maxWidth: .infinity)

                    Slider(value: $viewModel.signatureSize.width, in: 60...280, step: 4) {
                        Text(String(localized: "サイズ"))
                    }
                }

                Button(viewModel.signatureImage == nil ? String(localized: "署名を描く") : String(localized: "署名を描き直す")) {
                    isShowingDrawingSheet = true
                }
            }

            if let outputURL = viewModel.outputURL {
                Section(String(localized: "署名結果")) {
                    ShareLink(item: outputURL) {
                        Label(String(localized: "共有する"), systemImage: "square.and.arrow.up")
                    }
                }
            }

            Section {
                PrimaryButton(
                    title: String(localized: "PDFに署名する"),
                    systemImage: "signature",
                    isProcessing: viewModel.isProcessing,
                    isDisabled: !viewModel.canApplySignature
                ) {
                    Task { await viewModel.applySignature() }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

#Preview {
    SignatureView()
        .environment(SubscriptionManager())
}
