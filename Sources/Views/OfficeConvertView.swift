import SwiftUI
import UniformTypeIdentifiers

struct OfficeConvertView: View {
    @State private var viewModel = OfficeConvertViewModel()
    @State private var isShowingImporter = false

    var body: some View {
        BaseToolView(
            title: "PDF→Word/Excel/PPT",
            helpText: "PDFをWord・Excel・PowerPoint形式に変換します。"
        ) {
            Group {
                if viewModel.selectedURL == nil {
                    emptyStateView
                } else {
                    convertForm
                }
            }
        }
        .overlay {
            if viewModel.isProcessing {
                NeumorphicProcessingCard(
                    message: "\(viewModel.selectedFormat.label)に変換中…\(Int(viewModel.progress * 100))%"
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
            systemImage: "doc.text",
            title: "変換したいPDFファイルを選択してください",
            actionTitle: "PDFを選択"
        ) {
            isShowingImporter = true
        }
    }

    private var convertForm: some View {
        Form {
            Section("選択中のファイル") {
                Label(viewModel.selectedURL?.lastPathComponent ?? "", systemImage: "doc.text")
                    .lineLimit(1)

                Button("別のファイルを選択") {
                    isShowingImporter = true
                }
            }

            Section("変換フォーマット") {
                Picker("変換フォーマット", selection: $viewModel.selectedFormat) {
                    ForEach(OfficeFormat.allCases, id: \.self) { format in
                        Text(format.label).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            }

            if let outputURL = viewModel.outputURL {
                Section("変換結果") {
                    ShareLink(item: outputURL) {
                        Label("共有する", systemImage: "square.and.arrow.up")
                    }
                }
            }

            Section {
                PrimaryButton(
                    title: "変換する",
                    systemImage: "arrow.triangle.2.circlepath",
                    isProcessing: viewModel.isProcessing,
                    isDisabled: !viewModel.canConvert
                ) {
                    Task { await viewModel.convert() }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

#Preview {
    OfficeConvertView()
}
