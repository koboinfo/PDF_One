import SwiftUI
import UniformTypeIdentifiers

struct MergeView: View {
    @State private var viewModel = MergeViewModel()
    @State private var isShowingPicker = false
    @State private var isShowingShareSheet = false
    @State private var isShowingSaveNameAlert = false
    @State private var isShowingSaveExporter = false
    @State private var saveFileName = ""
    @State private var exportURL: URL?
    @State private var toast: ToastData?
    @State private var isShowingPaywall = false

    var body: some View {
        BaseToolView(
            title: String(localized: "PDF結合"),
            helpText: String(localized: "複数のPDFファイルを選択順に1つのPDFへ結合します。並び替えや削除は一覧からできます。"),
            onDropProviders: handleDrop
        ) {
            Group {
                if viewModel.selectedURLs.isEmpty {
                    emptyStateView
                } else {
                    MergeFileListView(viewModel: viewModel)
                }
            }
        } footer: {
            footerContent
        }
        .overlay {
            if viewModel.isProcessing {
                NeumorphicProcessingCard(message: String(localized: "結合中…"))
            }
        }
        .background {
            if let outputURL = viewModel.outputURL {
                ActivityPresenterView(activityItems: [outputURL], isPresented: $isShowingShareSheet)
            }
        }
        .toast($toast)
        .filePicker(.pdf(), isPresented: $isShowingPicker) { newURLs in
            viewModel.selectedURLs.append(contentsOf: newURLs)
        }
        .onChange(of: isShowingShareSheet) { wasShowing, isShowing in
            guard wasShowing, !isShowing else { return }
            presentAdIfEligible()
        }
        .onChange(of: viewModel.outputURL) { _, newValue in
            guard newValue != nil else { return }
            toast = ToastData(style: .success, message: String(localized: "PDFを結合しました"))
        }
        .alert(String(localized: "ファイル名を入力"), isPresented: $isShowingSaveNameAlert) {
            TextField(String(localized: "ファイル名"), text: $saveFileName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
            Button(String(localized: "キャンセル"), role: .cancel) {}
            Button(String(localized: "保存")) { prepareSaveExport() }
        } message: {
            Text(String(localized: "拡張子(.pdf)は自動で付与されます。"))
        }
        .sheet(isPresented: $isShowingSaveExporter) {
            if let exportURL {
                ModernSheet(title: String(localized: "保存先を選択")) {
                    DocumentExporterView(url: exportURL)
                }
            }
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

    private var emptyStateView: some View {
        EmptyStateView(
            systemImage: "doc.on.doc",
            title: String(localized: "結合したいPDFファイルを\nドラッグ＆ドロップ、またはタップして選択してください"),
            actionTitle: String(localized: "PDFを選択")
        ) {
            isShowingPicker = true
        }
    }

    @ViewBuilder
    private var footerContent: some View {
        if !viewModel.selectedURLs.isEmpty {
            VStack(spacing: 12) {
                if viewModel.outputURL != nil {
                    resultActionBar
                }

                PrimaryButton(
                    title: String(localized: "ファイルを追加"),
                    systemImage: "doc.badge.plus",
                    style: .bordered
                ) {
                    isShowingPicker = true
                }

                PrimaryButton(
                    title: String(localized: "PDFを結合する"),
                    systemImage: "square.and.arrow.down.on.square",
                    isProcessing: viewModel.isProcessing,
                    isDisabled: viewModel.selectedURLs.isEmpty
                ) {
                    Task { await viewModel.mergePDFs() }
                }
            }
        }
    }

    private var resultActionBar: some View {
        HStack(spacing: 10) {
            PrimaryButton(title: String(localized: "保存"), systemImage: "square.and.arrow.down", style: .bordered) {
                saveFileName = defaultSaveFileName()
                isShowingSaveNameAlert = true
            }
            PrimaryButton(title: String(localized: "共有"), systemImage: "square.and.arrow.up") {
                isShowingShareSheet = true
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

    private func presentAdIfEligible() {
        guard let vc = AdMobInterstitialManager.rootViewController else { return }
        AdMobInterstitialManager.shared.showAdIfEligible(from: vc) { didShowAd in
            isShowingPaywall = didShowAd
        }
    }

    private func writeTempPDF(_ data: Data) -> URL? {
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        guard (try? data.write(to: destinationURL, options: .atomic)) != nil else { return nil }
        return destinationURL
    }

    private func defaultSaveFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return "merged_\(formatter.string(from: Date()))"
    }

    /// ユーザー入力のファイル名からパス区切り文字等を除去し、拡張子を正規化する。
    private func sanitizedSaveFileName() -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        var name = saveFileName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: invalidChars)
            .joined()
        if name.isEmpty { name = defaultSaveFileName() }
        if name.hasSuffix(".pdf") { name = String(name.dropLast(4)) }
        return name
    }

    private func prepareSaveExport() {
        guard let outputURL = viewModel.outputURL else { return }
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(sanitizedSaveFileName())
            .appendingPathExtension("pdf")
        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.copyItem(at: outputURL, to: destination)
            exportURL = destination
            isShowingSaveExporter = true
        } catch {
            toast = ToastData(style: .error, message: String(localized: "保存準備に失敗しました"))
        }
    }
}

#Preview {
    MergeView()
}