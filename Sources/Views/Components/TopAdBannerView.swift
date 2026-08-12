import SwiftUI

/// 画面上部（ナビゲーションバー直下）に置く広告バナー。
/// 下部の`AdBannerView`が浮いたカード体裁なのに対し、こちらは全幅・角丸なし・下端hairlineで
/// ナビゲーションバーの延長として見えるようにする。高さ規格と表示制御は下部バナーと共有。
struct TopAdBannerView: View {
    /// 上下でバナー規格を揃えるため、下部バナーの高さをそのまま使う。
    static var height: CGFloat { AdBannerView.height }

    var body: some View {
        AdPlaceholderContent(cornerRadius: 0)
            .background(.bar)
            // 区切り線はバナーの高さ内に重ねる。VStackで足すと`adVisibility()`が固定する
            // バナー高さ(AdBannerView.height)をはみ出し、clippedで切り落とされてしまうため。
            .overlay(alignment: .bottom) {
                Divider()
            }
            .adVisibility()
    }
}

private struct TopAdBannerModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top) {
                TopAdBannerView()
            }
    }
}

extension View {
    /// 呼び出し位置の直上（例: ナビゲーションバーの直下）に広告枠を組み込む。
    func withTopAdBanner() -> some View {
        modifier(TopAdBannerModifier())
    }
}

#Preview(String(localized: "無料ユーザー")) {
    NavigationStack {
        ScrollView {
            ForEach(0..<20) { index in
                Text("行 \(index)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .withTopAdBanner()
        .navigationTitle(String(localized: "ツール"))
    }
    .environment(SubscriptionManager.preview(isProUser: false))
}

#Preview(String(localized: "Proユーザー")) {
    NavigationStack {
        ScrollView {
            ForEach(0..<20) { index in
                Text("行 \(index)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .withTopAdBanner()
        .navigationTitle(String(localized: "ツール"))
    }
    .environment(SubscriptionManager.preview(isProUser: true))
}
