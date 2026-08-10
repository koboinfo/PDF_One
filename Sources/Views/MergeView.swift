import SwiftUI
import UniformTypeIdentifiers

struct MergeView: View {
    @State private var viewModel = MergeViewModel()
    @State private var isShowingPicker = false
    @State private var isShowingShareSheet = false
    @State private var toast: ToastData?

    var body: some View {
        BaseToolView(
            title: "PDF結合",
            helpText: "複数のPDFファイルを選択順に1つのPDFへ結合します。並び替えや削除は一覧からできます。",
            onDropProviders: handleDrop
        ) {
            Group {
                if viewModel.selectedURLs.isEmpty {
                    emptyStateView
                } else {
                    MergeFileListView(viewModel: viewModel, isShowingShareSheet: $isShowingShareSheet)
                }
            }
        } footer: {
            footerContent
        }
        .overlay {
            if viewModel.isProcessing {
                NeumorphicProcessingCard(message: "結合中…")
            }
        }
        .toast($toast)
        .filePicker(.pdf(), isPresented: $isShowingPicker) { newURLs in
            viewModel.selectedURLs.append(contentsOf: newURLs)
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
            toast = ToastData(style: .success, message: "PDFを結合しました")
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
            systemImage: "doc.on.doc",
            title: "結合したいPDFファイルを\nドラッグ＆ドロップ、またはタップして選択してください",
            actionTitle: "PDFを選択"
        ) {
            isShowingPicker = true
        }
    }

    @ViewBuilder
    private var footerContent: some View {
        if !viewModel.selectedURLs.isEmpty {
            VStack(spacing: 12) {
                PrimaryButton(
                    title: "ファイルを追加",
                    systemImage: "doc.badge.plus",
                    style: .bordered
                ) {
                    isShowingPicker = true
                }

                PrimaryButton(
                    title: "PDFを結合する",
                    systemImage: "square.and.arrow.down.on.square",
                    isProcessing: viewModel.isProcessing,
                    isDisabled: viewModel.selectedURLs.isEmpty
                ) {
                    Task { await viewModel.mergePDFs() }
                }
            }
        }
    }

    /// ドラッグ&ドロップされたアイテムからPDFを読み込み、一時ファイルとして追加する。
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let pdfProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) }
        guard !pdfProviders.isEmpty else { return false }

        Task {
            var newURLs: [URL] = []
            for provider in pdfProviders {
                guard let data = await loadPDFData(from: provider), let url = writeTempPDF(data) else { continue }
                newURLs.append(url)
            }
            if !newURLs.isEmpty {
                viewModel.selectedURLs.append(contentsOf: newURLs)
            }
        }
        return true
    }

    private func loadPDFData(from provider: NSItemProvider) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(for: .pdf) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    private func writeTempPDF(_ data: Data) -> URL? {
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        guard (try? data.write(to: destinationURL, options: .atomic)) != nil else { return nil }
        return destinationURL
    }
}

#Preview {
    MergeView()
}