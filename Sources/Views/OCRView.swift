import SwiftUI
import UniformTypeIdentifiers

struct OCRView: View {
    @State private var viewModel = OCRViewModel()
    @State private var isShowingImporter = false
    @State private var isShowingShareSheet = false
    @State private var toast: ToastData?
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
            title: String(localized: "TXT抽出/OCR"),
            helpText: String(localized: "PDFからテキストを抽出します。コピーやTXTファイルとしての保存ができます。")
        ) {
            Group {
                if viewModel.selectedURL == nil {
                    emptyStateView
                } else {
                    ocrForm
                }
            }
        }
        .overlay {
            if viewModel.isProcessing {
                let truncatedProgress = Double(Int(viewModel.progress * 100)) / 100
                let percentText = truncatedProgress.formatted(.percent.precision(.fractionLength(0)))
                NeumorphicProcessingCard(
                    message: String(localized: "テキストを認識中…\(percentText)"),
                    progress: viewModel.progress
                )
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
        .sheet(isPresented: $isShowingShareSheet) {
            if let savedTextFileURL = viewModel.savedTextFileURL {
                ActivityView(activityItems: [savedTextFileURL])
            }
        }
        .toast($toast)
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
            systemImage: "text.viewfinder",
            title: String(localized: "テキストを抽出したいPDFファイルを選択してください"),
            actionTitle: String(localized: "PDFを選択")
        ) {
            isShowingImporter = true
        }
    }

    private var ocrForm: some View {
        Form {
            Section(String(localized: "選択中のファイル")) {
                Label(viewModel.selectedURL?.lastPathComponent ?? "", systemImage: "doc.text")
                    .lineLimit(1)
                Button(String(localized: "別のファイルを選択")) { isShowingImporter = true }
            }

            Section {
                PrimaryButton(
                    title: String(localized: "テキストを抽出"),
                    systemImage: "text.viewfinder",
                    isProcessing: viewModel.isProcessing,
                    isDisabled: !viewModel.canExtract
                ) {
                    Task { await viewModel.extractText() }
                }
            }

            if !viewModel.extractedText.isEmpty {
                Section(String(localized: "抽出結果")) {
                    TextEditor(text: .constant(viewModel.extractedText))
                        .frame(minHeight: 240)

                    Button {
                        viewModel.copyToClipboard()
                        toast = ToastData(style: .success, message: String(localized: "コピーしました"))
                    } label: {
                        Label(String(localized: "コピー"), systemImage: "doc.on.doc")
                    }

                    Button {
                        viewModel.saveAsTextFile()
                        isShowingShareSheet = true
                    } label: {
                        Label(String(localized: "TXTで保存"), systemImage: "square.and.arrow.down")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

#Preview {
    OCRView()
        .environment(SubscriptionManager())
}
