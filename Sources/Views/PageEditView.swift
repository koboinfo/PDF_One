import SwiftUI
import UniformTypeIdentifiers

struct PageEditView: View {
    @State private var viewModel = PageEditViewModel()
    @State private var isShowingImporter = false
    @State private var isShowingShareSheet = false

    var body: some View {
        BaseToolView(
            title: "ページ編集",
            helpText: "ページの並び替え・回転・削除ができます。ドラッグで順番を入れ替え、選択したページだけを抽出することもできます。"
        ) {
            Group {
                if viewModel.pageItems.isEmpty {
                    emptyStateView
                } else {
                    pageEditContent
                }
            }
        } footer: {
            footerContent
        }
        .overlay {
            if viewModel.isProcessing {
                NeumorphicProcessingCard(message: "処理中…")
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
            if let outputURL = viewModel.outputURL {
                ActivityView(activityItems: [outputURL])
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
            systemImage: "square.and.arrow.up.on.square.and.arrow.down",
            title: "編集したいPDFファイルを選択してください",
            actionTitle: "PDFを選択"
        ) {
            isShowingImporter = true
        }
    }

    private var pageEditContent: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("別のPDFを選択") { isShowingImporter = true }
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)

            PageEditGridView(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var footerContent: some View {
        if !viewModel.pageItems.isEmpty {
            VStack(spacing: 12) {
                if viewModel.outputURL != nil {
                    PrimaryButton(
                        title: "編集済みPDFを共有",
                        systemImage: "square.and.arrow.up",
                        style: .bordered
                    ) {
                        isShowingShareSheet = true
                    }
                }

                HStack(spacing: 12) {
                    PrimaryButton(
                        title: "選択ページを抽出",
                        systemImage: "doc.badge.arrow.up",
                        style: .bordered,
                        isDisabled: !viewModel.hasSelection
                    ) {
                        Task { await viewModel.extractSelectedPages() }
                    }

                    PrimaryButton(
                        title: "保存",
                        systemImage: "square.and.arrow.down.on.square",
                        isProcessing: viewModel.isProcessing,
                        isDisabled: viewModel.pageItems.isEmpty
                    ) {
                        Task { await viewModel.saveEditedPDF() }
                    }
                }
            }
        }
    }
}

#Preview {
    PageEditView()
}
