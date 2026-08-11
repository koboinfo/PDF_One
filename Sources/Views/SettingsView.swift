import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @State private var isShowingHelp = false
    @State private var isShowingPrivacyPolicy = false
    @State private var isShowingTermsOfService = false
    @State private var isShowingPaywall = false
    @State private var isRestoringSubscription = false
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(\.openURL) private var openURL

    private static let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    var body: some View {
        NavigationStack {
            Form {
                Section("サブスクリプション") {
                    if subscriptionManager.isSubscribed {
                        LabeledContent("プラン") {
                            Text(planLabel)
                                .foregroundStyle(.secondary)
                        }

                        if subscriptionManager.isInIntroductoryOffer {
                            LabeledContent("状態") {
                                Text("無料トライアル中")
                            }
                            .foregroundStyle(.orange)
                        }

                        if let expirationDate = subscriptionManager.activeExpirationDate {
                            LabeledContent(subscriptionManager.isInIntroductoryOffer ? "トライアル終了日" : "次回更新日") {
                                Text(expirationDate, style: .date)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button {
                            openURL(Self.manageSubscriptionsURL)
                        } label: {
                            infoRow(icon: "creditcard", title: "サブスクリプションを管理")
                        }
                        .tint(.primary)
                    } else {
                        Button {
                            isShowingPaywall = true
                        } label: {
                            infoRow(icon: "crown.fill", title: "Proにアップグレード")
                        }
                        .tint(.orange)
                    }

                    Button {
                        Task { await restoreSubscription() }
                    } label: {
                        if isRestoringSubscription {
                            HStack {
                                Text("購入を復元")
                                Spacer()
                                ProgressView()
                            }
                        } else {
                            infoRow(icon: "arrow.clockwise", title: "購入を復元")
                        }
                    }
                    .tint(.primary)
                    .disabled(isRestoringSubscription)
                }

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

                    Button {
                        isShowingTermsOfService = true
                    } label: {
                        infoRow(icon: "doc.plaintext", title: "利用規約")
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
            .sheet(isPresented: $isShowingTermsOfService) {
                TermsOfServiceView()
            }
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView()
            }
            .toast($viewModel.toast)
        }
    }

    private var planLabel: String {
        guard let activeProductID = subscriptionManager.activeProductID else { return "PDF One Pro" }
        return activeProductID == SubscriptionProductID.yearly.rawValue
            ? "PDF One Pro（年額）"
            : "PDF One Pro（月額）"
    }

    private func restoreSubscription() async {
        guard !isRestoringSubscription else { return }
        isRestoringSubscription = true
        defer { isRestoringSubscription = false }

        do {
            try await subscriptionManager.restorePurchases()
            viewModel.toast = subscriptionManager.isSubscribed
                ? ToastData(style: .success, message: "購入を復元しました")
                : ToastData(style: .error, message: "復元できる購入が見つかりませんでした")
        } catch {
            viewModel.toast = ToastData(style: .error, message: "復元に失敗しました")
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
        .environment(SubscriptionManager())
}
