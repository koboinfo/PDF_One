import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @State private var isShowingHelp = false
    @State private var isShowingPrivacyPolicy = false

    var body: some View {
        NavigationStack {
            Form {
                Section("ストレージ") {
                    LabeledContent("キャッシュサイズ") {
                        if viewModel.isCalculatingCacheSize {
                            ProgressView()
                        } else {
                            Text(viewModel.cacheSizeText)
                                .foregroundStyle(.secondary)
                        }
                    }

                    PrimaryButton(
                        title: "キャッシュを削除",
                        systemImage: "trash",
                        style: .bordered,
                        isProcessing: viewModel.isClearingCache,
                        isDisabled: viewModel.cacheSizeBytes == 0
                    ) {
                        Task { await viewModel.clearCache() }
                    }
                    .tint(.red)
                }

                Section("アプリ情報") {
                    infoRow(icon: "info.circle", title: "バージョン", value: viewModel.appVersionText)

                    Button {
                        isShowingHelp = true
                    } label: {
                        infoRow(icon: "questionmark.circle", title: "使い方ヘルプ")
                    }
                    .tint(.primary)

                    Button {
                        isShowingPrivacyPolicy = true
                    } label: {
                        infoRow(icon: "hand.raised", title: "プライバシーポリシー")
                    }
                    .tint(.primary)
                }
            }
            .navigationTitle("設定")
            .task {
                await viewModel.calculateCacheSize()
            }
            .sheet(isPresented: $isShowingHelp) {
                InfoSheet(
                    title: "使い方ヘルプ",
                    message: """
                    ・結合: 複数のPDFを1つにまとめます。
                    ・画像からPDF: 写真を選択してPDFに変換します。
                    ・圧縮: PDFのファイルサイズを軽量化します。
                    ・ページ編集: ページの回転・削除・抽出ができます。
                    """
                )
            }
            .sheet(isPresented: $isShowingPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .toast($viewModel.toast)
        }
    }

    private func infoRow(icon: String, title: String, value: String? = nil) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            if let value {
                Text(value)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct InfoSheet: View {
    let title: String
    let message: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(message)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
