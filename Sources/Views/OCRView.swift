import SwiftUI
import UniformTypeIdentifiers

struct OCRView: View {
    @State private var viewModel = OCRViewModel()
    @State private var isShowingImporter = false
    @State private var isShowingShareSheet = false
    @State private var toast: ToastData?

    var body: some View {
        BaseToolView(
            title: "TXT抽出/OCR",
            helpText: "PDFからテキストを抽出します。コピーやTXTファイルとしての保存ができます。"
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
                NeumorphicProcessingCard(
                    message: "テキストを認識中…\(Int(viewModel.progress * 100))%",
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
            systemImage: "text.viewfinder",
            title: "テキストを抽出したいPDFファイルを選択してください",
            actionTitle: "PDFを選択"
        ) {
            isShowingImporter = true
        }
    }

    private var ocrForm: some View {
        Form {
            Section("選択中のファイル") {
                Label(viewModel.selectedURL?.lastPathComponent ?? "", systemImage: "doc.text")
                    .lineLimit(1)
                Button("別のファイルを選択") { isShowingImporter = true }
            }

            Section {
                PrimaryButton(
                    title: "テキストを抽出",
                    systemImage: "text.viewfinder",
                    isProcessing: viewModel.isProcessing,
                    isDisabled: !viewModel.canExtract
                ) {
                    Task { await viewModel.extractText() }
                }
            }

            if !viewModel.extractedText.isEmpty {
                Section("抽出結果") {
                    TextEditor(text: .constant(viewModel.extractedText))
                        .frame(minHeight: 240)

                    Button {
                        viewModel.copyToClipboard()
                        toast = ToastData(style: .success, message: "コピーしました")
                    } label: {
                        Label("コピー", systemImage: "doc.on.doc")
                    }

                    Button {
                        viewModel.saveAsTextFile()
                        isShowingShareSheet = true
                    } label: {
                        Label("TXTで保存", systemImage: "square.and.arrow.down")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

#Preview {
    OCRView()
}
