import SwiftUI
import UniformTypeIdentifiers

struct CompressView: View {
    @State private var viewModel = CompressViewModel()
    @State private var isShowingPicker = false
    @State private var isShowingShareSheet = false
    @State private var toast: ToastData?
    @State private var isShowingPaywall = false

    var body: some View {
        BaseToolView(
            title: String(localized: "圧縮"),
            helpText: String(localized: "PDFの各ページをJPEGに再エンコードしてファイルサイズを圧縮します。圧縮強度は低・中・高から選べます。")
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
                NeumorphicProcessingCard(message: String(localized: "圧縮中…"))
            }
        }
        .toast($toast)
        .filePicker(.pdf(allowsMultipleSelection: false), isPresented: $isShowingPicker) { newURLs in
            guard let url = newURLs.first else { return }
            viewModel.selectedURL = url
        }
        .sheet(isPresented: $isShowingShareSheet, onDismiss: presentAdIfEligible) {
            if let outputURL = viewModel.outputURL {
                ModernSheet(title: String(localized: "共有")) {
                    ActivityView(activityItems: [outputURL])
                }
            }
        }
        .onChange(of: viewModel.outputURL) { _, newValue in
            guard newValue != nil else { return }
            toast = ToastData(style: .success, message: String(localized: "PDFを圧縮しました"))
            isShowingShareSheet = true
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView()
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

    private func presentAdIfEligible() {
        guard let vc = AdMobInterstitialManager.rootViewController else { return }
        AdMobInterstitialManager.shared.showAdIfEligible(from: vc) { didShowAd in
            isShowingPaywall = didShowAd
        }
    }

    private var emptyStateView: some View {
        EmptyStateView(
            systemImage: "arrow.down.right.and.arrow.up.left",
            title: String(localized: "圧縮したいPDFファイルを選択してください"),
            actionTitle: String(localized: "PDFを選択")
        ) {
            isShowingPicker = true
        }
    }

    private var compressionForm: some View {
        Form {
            Section(String(localized: "選択中のファイル")) {
                Label(viewModel.selectedURL?.lastPathComponent ?? "", systemImage: "doc.text")
                    .lineLimit(1)

                if let originalFileSizeBytes = viewModel.originalFileSizeBytes {
                    LabeledContent(String(localized: "元のサイズ"), value: CompressViewModel.formattedFileSize(originalFileSizeBytes))
                }

                Button(String(localized: "別のファイルを選択")) {
                    isShowingPicker = true
                }
            }

            Section(String(localized: "圧縮強度")) {
                Picker(String(localized: "圧縮強度"), selection: $viewModel.compressionQuality) {
                    ForEach(PDFCompressionQuality.selectableQualities, id: \.self) { quality in
                        Text(quality.label).tag(quality)
                    }
                }
                .pickerStyle(.segmented)
            }

            if viewModel.outputURL != nil {
                Section(String(localized: "圧縮結果")) {
                    if let compressedFileSizeBytes = viewModel.compressedFileSizeBytes {
                        LabeledContent(String(localized: "圧縮後のサイズ"), value: CompressViewModel.formattedFileSize(compressedFileSizeBytes))
                    }
                    if let reductionPercentText = viewModel.reductionPercentText {
                        LabeledContent(String(localized: "削減率"), value: reductionPercentText)
                    }

                    Button {
                        isShowingShareSheet = true
                    } label: {
                        Label(String(localized: "共有する"), systemImage: "square.and.arrow.up")
                    }
                    .tint(ToolIconType.compress.tint)
                }
            }

            Section {
                PrimaryButton(
                    title: String(localized: "圧縮する"),
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