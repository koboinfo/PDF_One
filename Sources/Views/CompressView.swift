import SwiftUI
import UniformTypeIdentifiers

struct CompressView: View {
    @State private var viewModel = CompressViewModel()
    @State private var isShowingPicker = false
    @State private var isShowingShareSheet = false
    @State private var toast: ToastData?

    var body: some View {
        BaseToolView(
            title: "圧縮",
            helpText: "PDFの各ページをJPEGに再エンコードしてファイルサイズを圧縮します。圧縮強度は低・中・高から選べます。"
        ) {
            Group {
                if viewModel.selectedURL == nil {
                    emptyStateView
                } else {
                    compressionForm
                }
            }
        }
        .overlay {
            if viewModel.isProcessing {
                NeumorphicProcessingCard(message: "圧縮中…")
            }
        }
        .toast($toast)
        .filePicker(.pdf(allowsMultipleSelection: false), isPresented: $isShowingPicker) { newURLs in
            guard let url = newURLs.first else { return }
            viewModel.selectedURL = url
        }
        .sheet(isPresented: $isShowingShareSheet) {
            if let outputURL = viewModel.outputURL {
                ModernSheet(title: "共有") {
                    ActivityView(activityItems: [outputURL])
                }
            }
        }
        .onChange(of: viewModel.outputURL) { _, newValue in
            guard newValue != nil else { return }
            toast = ToastData(style: .success, message: "PDFを圧縮しました")
            isShowingShareSheet = true
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
            systemImage: "arrow.down.right.and.arrow.up.left",
            title: "圧縮したいPDFファイルを選択してください",
            actionTitle: "PDFを選択"
        ) {
            isShowingPicker = true
        }
    }

    private var compressionForm: some View {
        Form {
            Section("選択中のファイル") {
                Label(viewModel.selectedURL?.lastPathComponent ?? "", systemImage: "doc.text")
                    .lineLimit(1)

                if let originalFileSizeBytes = viewModel.originalFileSizeBytes {
                    LabeledContent("元のサイズ", value: CompressViewModel.formattedFileSize(originalFileSizeBytes))
                }

                Button("別のファイルを選択") {
                    isShowingPicker = true
                }
            }

            Section("圧縮強度") {
                Picker("圧縮強度", selection: $viewModel.compressionQuality) {
                    ForEach(PDFCompressionQuality.selectableQualities, id: \.self) { quality in
                        Text(quality.label).tag(quality)
                    }
                }
                .pickerStyle(.segmented)
            }

            if viewModel.outputURL != nil {
                Section("圧縮結果") {
                    if let compressedFileSizeBytes = viewModel.compressedFileSizeBytes {
                        LabeledContent("圧縮後のサイズ", value: CompressViewModel.formattedFileSize(compressedFileSizeBytes))
                    }
                    if let reductionPercentText = viewModel.reductionPercentText {
                        LabeledContent("削減率", value: reductionPercentText)
                    }

                    Button {
                        isShowingShareSheet = true
                    } label: {
                        Label("共有する", systemImage: "square.and.arrow.up")
                    }
                    .tint(ToolIconType.compress.tint)
                }
            }

            Section {
                PrimaryButton(
                    title: "圧縮する",
                    systemImage: "arrow.down.circle.fill",
                    isProcessing: viewModel.isProcessing
                ) {
                    Task { await viewModel.compressPDF() }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

#Preview {
    CompressView()
}