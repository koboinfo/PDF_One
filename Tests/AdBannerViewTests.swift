import XCTest
@testable import PDF_One

/// 上下の広告バナー（`AdBannerView` / `TopAdBannerView`）は`AdVisibilityModifier`を通じて
/// `SubscriptionManager.isAdBannerVisible`で表示・非表示が切り替わり、非表示時は
/// `AdBannerView.height` ぶんの領域ごと高さ0に潰れる。
///
/// SwiftUIのレンダリング結果自体は検証できないため、ここではレイアウトの前提となる高さ規格と、
/// 表示・非表示を決めるロジック（Pro連動）を検証する。
/// StoreKit経由の購読状態遷移は`SubscriptionManagerTests`が担当するが、そちらは実行環境の
/// `SKTestSession`が使えないと動かないため、この判定ロジックはStoreKit非依存の
/// `SubscriptionManager.preview(isProUser:)`で常に検証できるようにしている。
@MainActor
final class AdBannerViewTests: XCTestCase {

    // MARK: - バナーの高さ規格

    func testBannerHeightMatchesStandardAdMobBannerSize() {
        XCTAssertEqual(AdBannerView.height, 50, "AdMobの標準バナーサイズ(kGADAdSizeBanner)は高さ50ptのため、これに合わせておく")
    }

    func testTopAndBottomBannersShareTheSameHeight() {
        XCTAssertEqual(
            TopAdBannerView.height,
            AdBannerView.height,
            "上下バナーは同じ広告規格を使う。片方だけ高さが変わるとsafeAreaInsetの余白が上下で食い違う"
        )
    }

    // MARK: - Pro連動（広告の表示・非表示）

    func testAdBannerIsVisibleForFreeUser() {
        let manager = SubscriptionManager.preview(isProUser: false)

        XCTAssertTrue(manager.isAdBannerVisible, "無料ユーザーには上下とも広告バナーが表示されるべき")
    }

    func testAdBannerIsHiddenForProUser() {
        let manager = SubscriptionManager.preview(isProUser: true)

        XCTAssertFalse(manager.isAdBannerVisible, "Proユーザーには広告バナーが表示されず、領域も高さ0まで潰されるべき")
    }

    func testAdBannerVisibilityIsAlwaysTheInverseOfProStatus() {
        for isProUser in [true, false] {
            let manager = SubscriptionManager.preview(isProUser: isProUser)

            XCTAssertEqual(manager.isProUser, isProUser)
            XCTAssertNotEqual(
                manager.isAdBannerVisible,
                manager.isProUser,
                "isAdBannerVisibleはisProUserの反転でなければならない（両立するとProユーザーに広告が出る）"
            )
        }
    }
}
