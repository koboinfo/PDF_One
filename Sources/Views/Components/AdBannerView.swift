import SwiftUI

/// 広告枠の中身（プレースホルダー）。上下バナーで共有する。
/// 広告SDK導入後は、このViewの内部を`UIViewRepresentable`でラップした実広告ビューに差し替える。
/// 表示・非表示の制御は`AdVisibilityModifier`が担うため、ここではレイアウトと見た目だけを持つ。
struct AdPlaceholderContent: View {
    /// 角丸半径。下部バナーはカード体裁、上部バナーはナビゲーションバーに貼り付く体裁のため0を渡す。
    var cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            )
            .overlay(
                Text(String(localized: "広告（準備中）"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            )
            .frame(height: AdBannerView.height)
    }
}

/// `SubscriptionManager.isAdBannerVisible`に応じて広告枠を出し入れする共通モディファイア。
/// Proユーザーには高さ0までアニメーションさせ、レイアウト上の領域・タップ判定・VoiceOverの
/// 読み上げ対象のいずれからも完全に取り除く。
struct AdVisibilityModifier: ViewModifier {
    @Environment(SubscriptionManager.self) private var subscriptionManager

    private var isVisible: Bool { subscriptionManager.isAdBannerVisible }

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .frame(height: isVisible ? AdBannerView.height : 0)
            .clipped()
            .allowsHitTesting(isVisible)
            .accessibilityHidden(!isVisible)
            .animation(.easeInOut(duration: 0.25), value: isVisible)
    }
}

extension View {
    /// 広告枠にPro連動の表示・非表示アニメーションを適用する。
    func adVisibility() -> some View {
        modifier(AdVisibilityModifier())
    }
}

/// 浮いた角丸カード体裁の広告バナー。
///
/// 広告の配置は`TopAdBannerView`による上部1枚に統一しているため、現在このViewは画面には出ない。
/// 上下バナー共通の高さ規格（`height`）の置き場所であり、下部配置に戻す場合の実装でもある。
/// 下部に足す`withBottomAdBanner()`は、上部と二重に出る事故を防ぐため意図的に用意していない。
struct AdBannerView: View {
    /// 標準的なバナー広告の高さ（AdMobのAdSizeBannerに合わせる）。上下バナーで共通の規格。
    static let height: CGFloat = 50

    var body: some View {
        AdPlaceholderContent(cornerRadius: 12)
            .padding(.horizontal, 16)
            .adVisibility()
    }
}

#Preview(String(localized: "無料ユーザー")) {
    VStack {
        Spacer()
        AdBannerView()
        Spacer()
    }
    .environment(SubscriptionManager.preview(isProUser: false))
}

#Preview(String(localized: "Proユーザー")) {
    VStack {
        Spacer()
        AdBannerView()
        Spacer()
    }
    .environment(SubscriptionManager.preview(isProUser: true))
}
