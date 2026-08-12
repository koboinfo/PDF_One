import SwiftUI
import UniformTypeIdentifiers

struct PDFToJPGView: View {
    @State private var viewModel = PDFToJPGViewModel()
    @State private var isShowingImporter = false
    @State private var isShowingShareSheet = false

    var body: some View {
        BaseToolView(
            title: "PDF→JPG",
            helpText: String(localized: "PDFの各ページをJPG画像に変換して保存・共有します。")
        ) {
            Group {
                if viewModel.pages.isEmpty {
                    emptyStateView
                } else {
                    pdfToJPGContent
                }
            }
        } footer: {
            footerContent
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
        .sheet(isPresented: $isShowingShareSheet) {
            ActivityView(activityItems: viewModel.outputURLs)
        }
        .onChange(of: viewModel.outputURLs) { _, newValue in
            guard !newValue.isEmpty else { return }
            isShowingShareSheet = true
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
            systemImage: "photo.on.rectangle",
            title: String(localized: "JPGに変換したいPDFファイルを選択してください"),
            actionTitle: String(localized: "PDFを選択")
        ) {
            isShowingImporter = true
        }
    }

    private var pdfToJPGContent: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(String(localized: "別のPDFを選択")) { isShowingImporter = true }
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)

            PDFToJPGGridView(pages: viewModel.pages)
        }
    }

    @ViewBuilder
    private var footerContent: some View {
        if !viewModel.pages.isEmpty {
            PrimaryButton(
                title: String(localized: "画像として保存・共有"),
                systemImage: "square.and.arrow.up",
                isProcessing: viewModel.isProcessing
            ) {
                Task { await viewModel.exportAllAsJPEGs() }
            }
        }
    }
}

#Preview {
    PDFToJPGView()
}
