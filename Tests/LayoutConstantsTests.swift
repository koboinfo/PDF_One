import XCTest
@testable import PDF_One

/// `LayoutConstants`は「実行ボタンやリスト末尾がタブバー・広告に隠れない」ためのレイアウト基準値。
/// SwiftUIのレンダリング結果は検証できないため、ここでは隠れないことを保証する数値の関係
/// （不変条件）と、コンポーネント側の寸法と基準値が乖離していないことを検証する。
final class LayoutConstantsTests: XCTestCase {

    // MARK: - コンポーネント実寸との整合

    func testTabBarHeightMatchesModernTabBarComposition() {
        // 内訳: アイコン22 + spacing5 + インジケータ4 = 31、ボタン縦padding 6×2 = 12、HStack縦padding 10×2 = 20。
        let composedHeight: CGFloat = (22 + 5 + 4) + (6 * 2) + (10 * 2)

        XCTAssertEqual(
            ModernTabBar.height,
            composedHeight,
            "ModernTabBarの構成を変えたらheightも更新すること。ずれるとタブバーにボタンが隠れる"
        )
        XCTAssertEqual(LayoutConstants.tabBarHeight, ModernTabBar.height)
    }

    func testAdBannerHeightIsDerivedFromAdBannerView() {
        XCTAssertEqual(
            LayoutConstants.adBannerHeight,
            AdBannerView.height,
            "広告高さは実体のバナーから導出する。直書きすると規格変更時に余白だけ取り残される"
        )
    }

    // MARK: - 不変条件（ボタンが隠れないこと）

    func testTabBarClearanceCoversBarHeightAndItsBottomPadding() {
        XCTAssertEqual(
            LayoutConstants.tabBarClearance,
            LayoutConstants.tabBarHeight + LayoutConstants.tabBarBottomPadding,
            "タブバーが専有する高さは、バー自体の高さと下余白の合計でなければならない"
        )
    }

    func testScrollBottomInsetLeavesRoomBeyondTheTabBar() {
        XCTAssertGreaterThan(
            LayoutConstants.scrollBottomInset,
            LayoutConstants.tabBarClearance,
            "スクロール末尾の余白がタブバーの専有高以下だと、最後の要素がバーに隠れる"
        )
        XCTAssertEqual(
            LayoutConstants.scrollBottomInset,
            LayoutConstants.tabBarClearance + LayoutConstants.contentBottomBreathingSpace
        )
    }

    func testAllSpacingConstantsArePositive() {
        let constants: [(String, CGFloat)] = [
            ("tabBarHeight", LayoutConstants.tabBarHeight),
            ("tabBarBottomPadding", LayoutConstants.tabBarBottomPadding),
            ("adBannerHeight", LayoutConstants.adBannerHeight),
            ("screenHorizontalPadding", LayoutConstants.screenHorizontalPadding),
            ("contentBottomBreathingSpace", LayoutConstants.contentBottomBreathingSpace),
            ("toolHeaderTopPadding", LayoutConstants.toolHeaderTopPadding),
            ("toolHeaderBottomPadding", LayoutConstants.toolHeaderBottomPadding),
            ("toolFooterTopPadding", LayoutConstants.toolFooterTopPadding),
            ("toolFooterBottomPadding", LayoutConstants.toolFooterBottomPadding)
        ]

        for (name, value) in constants {
            XCTAssertGreaterThan(value, 0, "\(name)は正の値でなければならない")
        }
    }
}
