import SwiftUI
import UniformTypeIdentifiers

struct SplitPDFView: View {
    @State private var viewModel = SplitPDFViewModel()
    @State private var isShowingPicker = false
    @State private var isShowingShareSheet = false
    @State private var toast: ToastData?

    var body: some View {
        BaseToolView(
            title: String(localized: "PDF分割"),
            helpText: String(localized: "ページ範囲をカンマ区切りで指定すると、範囲ごとに複数のPDFファイルへ分割します（例: 1-3, 4-5）。")
        ) {
            Group {
                if viewModel.sourceURL == nil {
                    emptyStateView
                } else {
                    splitForm
                }
            }
        }
        .overlay {
            if viewModel.isProcessing {
                NeumorphicProcessingCard(message: String(localized: "分割中…"))
            }
        }
        .toast($toast)
        .filePicker(.pdf(allowsMultipleSelection: false), isPresented: $isShowingPicker) { newURLs in
            guard let url = newURLs.first else { return }
            viewModel.sourceURL = url
        }
        .sheet(isPresented: $isShowingShareSheet) {
            ModernSheet(title: String(localized: "共有")) {
                ActivityView(activityItems: viewModel.outputURLs)
            }
        }
        .onChange(of: viewModel.outputURLs) { _, newValue in
            guard !newValue.isEmpty else { return }
            toast = ToastData(style: .success, message: String(localized: "\(newValue.count)個のファイルに分割しました"))
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
            systemImage: "square.split.2x1",
            title: String(localized: "分割したいPDFファイルを選択してください"),
            actionTitle: String(localized: "PDFを選択")
        ) {
            isShowingPicker = true
        }
    }

    private var splitForm: some View {
        Form {
            Section(String(localized: "選択中のファイル")) {
                Label(viewModel.sourceURL?.lastPathComponent ?? "", systemImage: "doc.text")
                    .lineLimit(1)

                LabeledContent(String(localized: "総ページ数"), value: "\(viewModel.pageCount)")

                Button(String(localized: "別のファイルを選択")) {
                    isShowingPicker = true
                }
            }

            Section(String(localized: "分割範囲")) {
                TextField(String(localized: "例: 1-3, 4-5"), text: $viewModel.rangeText)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)

                Text(String(localized: "カンマ区切りでページ範囲を指定してください。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !viewModel.outputURLs.isEmpty {
                Section(String(localized: "分割結果")) {
                    Text(String(localized: "\(viewModel.outputURLs.count)個のファイルに分割しました。"))

                    Button {
                        isShowingShareSheet = true
                    } label: {
                        Label(String(localized: "共有する"), systemImage: "square.and.arrow.up")
                    }
                    .tint(ToolIconType.splitPDF.tint)
                }
            }

            Section {
                PrimaryButton(
                    title: String(localized: "分割する"),
                    systemImage: "square.split.2x1",
                    isProcessing: viewModel.isProcessing
                ) {
                    Task { await viewModel.splitPDF() }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

#Preview {
    SplitPDFView()
}
