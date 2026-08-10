import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// 画像→PDF変換画面。空状態・選択リスト・変換結果の3状態を切り替える、他画面のデザインテンプレート。
struct ImageToPDFView: View {
    @State private var viewModel = ImageToPDFViewModel()
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var isShowingPhotoPicker = false
    @State private var isShowingShareSheet = false
    @State private var isShowingSaveExporter = false

    var body: some View {
        BaseToolView(
            title: "画像→PDF",
            helpText: "複数の画像を選んでまとめて1つのPDFに変換します。並び順は「編集」から入れ替えできます。",
            onDropProviders: viewModel.outputURL == nil ? handleDrop : nil
        ) {
            Group {
                if let outputURL = viewModel.outputURL {
                    ResultView(outputURL: outputURL, pageCount: viewModel.images.count, fileSizeText: viewModel.outputFileSizeText)
                } else if viewModel.images.isEmpty {
                    emptyStateView
                } else {
                    ImageToPDFListView(viewModel: viewModel)
                }
            }
        } footer: {
            footerContent
        }
        .overlay {
            if viewModel.isProcessing {
                NeumorphicProcessingCard(message: "変換中…")
            }
        }
        .photosPicker(isPresented: $isShowingPhotoPicker, selection: $photoPickerItems, matching: .images)
        .onChange(of: photoPickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                await appendImages(from: newItems)
                photoPickerItems = []
            }
        }
        .sheet(isPresented: $isShowingShareSheet) {
            if let outputURL = viewModel.outputURL {
                ModernSheet(title: "共有") {
                    ActivityView(activityItems: [outputURL])
                }
            }
        }
        .sheet(isPresented: $isShowingSaveExporter) {
            if let outputURL = viewModel.outputURL {
                ModernSheet(title: "保存先を選択") {
                    DocumentExporterView(url: outputURL)
                }
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
            systemImage: "photo.on.rectangle.angled",
            title: "PDFに変換したい画像をドラッグ＆ドロップ、\nまたは選択してください",
            actionTitle: "画像を選択"
        ) {
            isShowingPhotoPicker = true
        }
    }

    @ViewBuilder
    private var footerContent: some View {
        if let outputURL = viewModel.outputURL {
            resultActionBar(outputURL: outputURL)
        } else if !viewModel.images.isEmpty {
            VStack(spacing: 12) {
                PhotosPicker(selection: $photoPickerItems, matching: .images) {
                    Label("画像を追加", systemImage: "photo.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                PrimaryButton(
                    title: "PDFに変換",
                    systemImage: "doc.badge.arrow.up",
                    isProcessing: viewModel.isProcessing,
                    isDisabled: viewModel.images.isEmpty
                ) {
                    Task { await viewModel.createPDF() }
                }
            }
        }
    }

    private func resultActionBar(outputURL: URL) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                PrimaryButton(title: "保存", systemImage: "square.and.arrow.down", style: .bordered) {
                    isShowingSaveExporter = true
                }
                PrimaryButton(title: "共有", systemImage: "square.and.arrow.up") {
                    isShowingShareSheet = true
                }
            }

            PrimaryButton(
                title: "Cloudinaryにアップロード（準備中）",
                systemImage: "icloud.and.arrow.up",
                style: .bordered,
                isDisabled: true
            ) {}

            Button("やり直す") { viewModel.reset() }
                .font(.footnote.weight(.medium))
                .padding(.top, 2)
        }
    }

    private func appendImages(from items: [PhotosPickerItem]) async {
        var newURLs: [URL] = []

        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            guard let url = writeTempJPEG(data) else { continue }
            newURLs.append(url)
        }

        viewModel.appendLocalImages(urls: newURLs)
    }

    /// ドラッグ&ドロップされたアイテムから画像データを読み込み、一時ファイルとして追加する。
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let imageProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
        guard !imageProviders.isEmpty else { return false }

        Task {
            var newURLs: [URL] = []
            for provider in imageProviders {
                guard let data = await loadImageData(from: provider), let url = writeTempJPEG(data) else { continue }
                newURLs.append(url)
            }
            if !newURLs.isEmpty {
                viewModel.appendLocalImages(urls: newURLs)
            }
        }
        return true
    }

    private func loadImageData(from provider: NSItemProvider) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(for: .image) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    private func writeTempJPEG(_ data: Data) -> URL? {
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        guard (try? data.write(to: destinationURL, options: .atomic)) != nil else { return nil }
        return destinationURL
    }
}

/// 変換完了画面。チェックマークアニメーション、PDFプレビューカード、下部固定のアクションボタンで構成する。
private struct ResultView: View {
    let outputURL: URL
    let pageCount: Int
    let fileSizeText: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                SuccessCheckmark()
                    .padding(.top, 24)

                VStack(spacing: 4) {
                    Text("PDFを作成しました")
                        .font(.title3.bold())
                    Text("下のボタンから保存・共有できます")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ResultPreviewCard(
                    url: outputURL,
                    subtitle: [pageSummary, fileSizeText].compactMap { $0 }.joined(separator: " ・ ")
                )
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 24)
        }
    }

    private var pageSummary: String { "\(pageCount)ページ" }
}

/// トリム済みの円弧とチェックマークを描画して完了を演出するアニメーション。
private struct SuccessCheckmark: View {
    @State private var circleProgress: CGFloat = 0
    @State private var checkProgress: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: circleProgress)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 84, height: 84)
                .rotationEffect(.degrees(-90))

            CheckmarkShape()
                .trim(from: 0, to: checkProgress)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                .frame(width: 36, height: 28)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) {
                circleProgress = 1
            }
            withAnimation(.easeOut(duration: 0.35).delay(0.4)) {
                checkProgress = 1
            }
        }
    }
}

private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.width * 0.38, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.1))
        return path
    }
}

#Preview {
    ImageToPDFView()
}
