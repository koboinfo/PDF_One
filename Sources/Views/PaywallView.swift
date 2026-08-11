import StoreKit
import SwiftUI

/// 課金ゲート対象ツール（署名・OCR・透かし・Office変換）を開こうとした際、または設定画面からのアップグレード導線として表示するペイウォールの中身。
/// `NavigationStack`を持たない純粋なViewとして、モーダル表示（`PaywallView`）とツール画面へのインライン差し替えの両方から共有する。
struct PaywallContentView: View {
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: PaywallViewModel?
    @State private var isShowingTerms = false
    @State private var isShowingPrivacyPolicy = false

    var body: some View {
        ScrollView {
            if let viewModel {
                content(viewModel)
            } else {
                ProgressView()
                    .padding(.top, 80)
            }
        }
        .background(AppBackground())
        .task {
            if viewModel == nil {
                viewModel = PaywallViewModel(subscriptionManager: subscriptionManager)
            }
            await viewModel?.onAppear()
        }
        .sheet(isPresented: $isShowingTerms) { TermsOfServiceView() }
        .sheet(isPresented: $isShowingPrivacyPolicy) { PrivacyPolicyView() }
    }

    @ViewBuilder
    private func content(_ viewModel: PaywallViewModel) -> some View {
        VStack(spacing: 24) {
            header
            featureList

            if viewModel.isLoadingProducts && viewModel.products.isEmpty {
                ProgressView()
                    .padding(.top, 20)
            } else if viewModel.products.isEmpty {
                Text("プランを取得できませんでした。通信環境をご確認のうえ、もう一度お試しください。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else {
                planPicker(viewModel)

                if let message = viewModel.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                PrimaryButton(
                    title: ctaTitle(viewModel),
                    systemImage: "crown.fill",
                    isProcessing: viewModel.isPurchasing,
                    isDisabled: viewModel.selectedProduct == nil
                ) {
                    Task {
                        if await viewModel.purchase() {
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal, 20)

                restoreButton(viewModel)
                legalFooter
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 32)
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.14))
                    .frame(width: 72, height: 72)
                Image(systemName: "crown.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.orange)
            }
            Text("PDF One Pro")
                .font(.title2.weight(.bold))
            Text("OCR・Office変換・透かし・電子署名を無制限に")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 8)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(icon: "text.viewfinder", text: "OCRで画像・PDFの文字を認識")
            featureRow(icon: "doc.text", text: "PDF↔Word/Excel/PowerPoint変換")
            featureRow(icon: "drop", text: "透かしの追加")
            featureRow(icon: "signature", text: "電子署名")
            featureRow(icon: "sparkles", text: "今後追加される新機能も追加費用なし")
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 8)
        )
        .padding(.horizontal, 20)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.orange)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }

    private func planPicker(_ viewModel: PaywallViewModel) -> some View {
        VStack(spacing: 12) {
            ForEach(viewModel.products, id: \.id) { product in
                planCard(product, viewModel: viewModel)
            }
        }
        .padding(.horizontal, 20)
    }

    private func planCard(_ product: Product, viewModel: PaywallViewModel) -> some View {
        let isSelected = viewModel.selectedProductID == product.id
        let isYearly = product.id == SubscriptionProductID.yearly.rawValue
        let isEligibleForTrial = viewModel.isEligibleForTrial(product)

        return Button {
            viewModel.select(product)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(product.displayName)
                            .font(.subheadline.weight(.semibold))
                        if isYearly {
                            Text("お得")
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.16), in: Capsule())
                                .foregroundStyle(.orange)
                        }
                    }
                    if isEligibleForTrial {
                        Text("7日間無料トライアル付き")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.subheadline.weight(.semibold))
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.orange : Color.secondary.opacity(0.3))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? Color.orange : Color.black.opacity(0.08), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func restoreButton(_ viewModel: PaywallViewModel) -> some View {
        Button {
            Task {
                await viewModel.restore()
                if subscriptionManager.isProUser {
                    dismiss()
                }
            }
        } label: {
            if viewModel.isRestoring {
                ProgressView()
            } else {
                Text("購入を復元")
                    .font(.footnote.weight(.medium))
            }
        }
        .padding(.top, 4)
    }

    private var legalFooter: some View {
        VStack(spacing: 6) {
            Text("""
            プランは自動更新されます。無料トライアル終了の24時間前までに解約しない場合、選択したプランの料金が自動的に課金されます。\
            購読の管理・解約は「設定」>Apple ID>「サブスクリプション」からいつでも行えます。
            """)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            HStack(spacing: 16) {
                Button("利用規約") { isShowingTerms = true }
                Button("プライバシーポリシー") { isShowingPrivacyPolicy = true }
            }
            .font(.caption2)
        }
        .padding(.top, 8)
    }

    private func ctaTitle(_ viewModel: PaywallViewModel) -> String {
        if let product = viewModel.selectedProduct, viewModel.isEligibleForTrial(product) {
            return "7日間無料で始める"
        }
        return "購入する"
    }
}

/// `PaywallContentView`をモーダル（sheet）表示用に`NavigationStack`と閉じるボタンで包んだもの。
/// ツール画面へのインライン差し替えでは、二重`NavigationStack`を避けるため`PaywallContentView`を直接使う。
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PaywallContentView()
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
        }
    }
}

#Preview {
    PaywallView()
        .environment(SubscriptionManager())
}
