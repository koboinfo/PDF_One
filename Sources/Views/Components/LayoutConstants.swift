import SwiftUI

/// アプリ全体で共有するレイアウト基準値。
///
/// フローティングタブバーと広告バナーは`safeAreaInset`で画面端に重ねているため、
/// 各画面が「下端にどれだけ空けるべきか」を個別のマジックナンバーで持つと必ず食い違う。
/// ここに一元化し、寸法は可能な限り実体のView（`ModernTabBar` / `AdBannerView`）から
/// 導出することで、コンポーネント側の変更と基準値の乖離を防ぐ。
enum LayoutConstants {

    // MARK: - タブバー

    /// フローティングタブバーの実高。`ModernTabBar`自身の構成から導出する。
    static var tabBarHeight: CGFloat { ModernTabBar.height }

    /// タブバーと画面下端（セーフエリア上端）の間に置く余白。
    static let tabBarBottomPadding: CGFloat = 8

    /// タブバーが専有する下端の高さ。スクロール内容がこの領域に入ると隠れる。
    static var tabBarClearance: CGFloat { tabBarHeight + tabBarBottomPadding }

    // MARK: - 広告

    /// 広告バナーの高さ。上部・下部で規格を共有する。
    static var adBannerHeight: CGFloat { AdBannerView.height }

    // MARK: - 余白

    /// 画面左右の標準余白。
    static let screenHorizontalPadding: CGFloat = 20

    /// 最終要素とタブバーの間に視覚的に残す余白。ボタンがバーに接して見えるのを防ぐ。
    static let contentBottomBreathingSpace: CGFloat = 12

    /// スクロール可能な内容の末尾に確保する余白。
    /// タブバーは`safeAreaInset`で重ねられるが`NavigationStack`の内側へ伝播しないため、
    /// 各タブのルートで明示的にこの分を空ける必要がある。
    static var scrollBottomInset: CGFloat { tabBarClearance + contentBottomBreathingSpace }

    // MARK: - ツール画面（BaseToolView）

    /// ツール画面のヘッダー/フッターの上下余白。
    static let toolHeaderTopPadding: CGFloat = 12
    static let toolHeaderBottomPadding: CGFloat = 8
    static let toolFooterTopPadding: CGFloat = 12
    static let toolFooterBottomPadding: CGFloat = 8
}

/// タブバーに隠れないよう、内容の下端に`LayoutConstants.scrollBottomInset`分の余白を確保する。
/// `safeAreaInset`で入れることで、`ScrollView` / `List` / `Form`のスクロール範囲にも
/// 正しく反映される（`padding`だと内容が固定でずれるだけでスクロールしきれない）。
private struct TabBarClearanceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: LayoutConstants.scrollBottomInset)
            }
    }
}

extension View {
    /// タブバー分の下端クリアランスを確保する。タブのルート画面とツール詳細画面で使う。
    func tabBarClearance() -> some View {
        modifier(TabBarClearanceModifier())
    }
}
