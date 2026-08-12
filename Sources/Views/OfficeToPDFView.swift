import SwiftUI
import UniformTypeIdentifiers

struct OfficeToPDFView: View {
    @State private var viewModel = OfficeToPDFViewModel()
    @State private var isShowingImporter = false
    @Environment(SubscriptionManager.self) private var subscriptionManager

    private var officeContentTypes: [UTType] {
        ["docx", "doc", "xlsx", "xls", "pptx", "ppt"].compactMap { UTType(filenameExtension: $0) }
    }

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
            title: "Word/Excel/PPT→PDF",
            helpText: String(localized: "Word・Excel・PowerPoint形式のファイルをPDFに変換します。")
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
                    message: String(localized: "PDFに変換中…\(Int(viewModel.progress * 100))%"),
                    progress: viewModel.progress
                )
            }
        }
        .fileImporter(isPresented: $isShowingImporter, allowedContentTypes: officeContentTypes) { result in
            switch result {
            case .success(let url):
                viewModel.selectedURL = url
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
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
            systemImage: "doc.badge.plus",
            title: String(localized: "変換したいWord/Excel/PowerPointファイルを選択してください"),
            actionTitle: String(localized: "ファイルを選択")
        ) {
            isShowingImporter = true
        }
    }

    private var convertForm: some View {
        Form {
            Section(String(localized: "選択中のファイル")) {
                Label(viewModel.selectedURL?.lastPathComponent ?? "", systemImage: "doc")
                    .lineLimit(1)

                Button(String(localized: "別のファイルを選択")) {
                    isShowingImporter = true
                }
            }

            if viewModel.detectedFormat == nil {
                Section {
                    Label(String(localized: "対応していないファイル形式です。"), systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }

            if let outputURL = viewModel.outputURL {
                Section(String(localized: "変換結果")) {
                    ShareLink(item: outputURL) {
                        Label(String(localized: "共有する"), systemImage: "square.and.arrow.up")
                    }
                }
            }

            Section {
                PrimaryButton(
                    title: String(localized: "PDFに変換する"),
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
    OfficeToPDFView()
        .environment(SubscriptionManager())
}
