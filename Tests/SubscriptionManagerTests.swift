import StoreKit
import StoreKitTest
import XCTest
@testable import PDF_One

/// `StoreKitTest`（`SKTestSession`）を使い、`Subscriptions.storekit`のローカル設定に対して
/// 購入・トライアル・キャンセル・期限切れ・返金・復元の各エッジケースを実機同等の挙動で検証する。
@MainActor
final class SubscriptionManagerTests: XCTestCase {
    private var session: SKTestSession!

    override func setUpWithError() throws {
        try super.setUpWithError()
        if let configURL = Bundle(for: Self.self).url(forResource: "Subscriptions", withExtension: "storekit") ?? Bundle.main.url(forResource: "Subscriptions", withExtension: "storekit") {
            session = try SKTestSession(contentsOf: configURL)
        } else {
            session = try SKTestSession(configurationFileNamed: "Subscriptions")
        }
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        session.timeRate = .realTime
    }

    override func tearDownWithError() throws {
        session.clearTransactions()
        session = nil
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func makeManager() -> SubscriptionManager {
        let defaults = UserDefaults(suiteName: "SubscriptionManagerTests-\(UUID().uuidString)")!
        return SubscriptionManager(userDefaults: defaults)
    }

    private func testTransaction(for productID: SubscriptionProductID) throws -> SKTestTransaction {
        try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == productID.rawValue })
    }

    /// `SKTestSession`側の状態変更（解約・失効・返金）が`Transaction.updates`経由で
    /// `SubscriptionManager`に反映されるまで、固定スリープの代わりに短間隔でポーリングして待つ。
    /// タイムアウトしても最後に`refreshEntitlements()`を呼んで確定状態にする。
    private func waitUntil(
        timeout: TimeInterval = 3,
        condition: () -> Bool,
        manager: SubscriptionManager
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            await manager.refreshEntitlements()
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        await manager.refreshEntitlements()
    }

    // MARK: - Products

    func testLoadProductsPopulatesMonthlyAndYearlySortedByPrice() async throws {
        let manager = makeManager()
        await manager.loadProducts()

        XCTAssertEqual(manager.products.map(\.id), [
            SubscriptionProductID.monthly.rawValue,
            SubscriptionProductID.yearly.rawValue
        ])
    }

    // MARK: - Purchase

    func testPurchaseGrantsEntitlementAndCachesLocally() async throws {
        let manager = makeManager()
        await manager.loadProducts()
        let monthly = try XCTUnwrap(manager.product(for: .monthly))

        let result = try await manager.purchase(monthly)

        XCTAssertTrue(result)
        XCTAssertTrue(manager.isProUser)
        XCTAssertEqual(manager.purchasedProductIDs, [SubscriptionProductID.monthly.rawValue])
        XCTAssertEqual(manager.activeProductID, SubscriptionProductID.monthly.rawValue)
    }

    func testFreeTrialAppliesIntroductoryOfferWithSevenDayExpiration() async throws {
        let manager = makeManager()
        await manager.loadProducts()
        let monthly = try XCTUnwrap(manager.product(for: .monthly))

        // 新規セッションでは同一サブスクリプショングループの購読履歴がないため、トライアル対象となる。
        let isEligible = await manager.isEligibleForIntroOffer(monthly)
        XCTAssertTrue(isEligible)

        try await manager.purchase(monthly)

        XCTAssertTrue(manager.isProUser)
        XCTAssertTrue(manager.isInIntroductoryOffer)

        let expirationDate = try XCTUnwrap(manager.activeExpirationDate)
        let daysUntilExpiration = Calendar.current.dateComponents(
            [.day],
            from: Date(),
            to: expirationDate
        ).day ?? 0
        XCTAssertTrue((6...7).contains(daysUntilExpiration), "7日間トライアルの失効日は6〜7日後であるべき（実測: \(daysUntilExpiration)日）")
    }

    func testIsEligibleForIntroOfferBecomesFalseAfterSubscribingInSameGroup() async throws {
        let manager = makeManager()
        await manager.loadProducts()
        let monthly = try XCTUnwrap(manager.product(for: .monthly))
        let yearly = try XCTUnwrap(manager.product(for: .yearly))

        try await manager.purchase(monthly)

        // 月額でトライアルを使用済みのため、同一グループの年額プランはもうトライアル対象外になる。
        let yearlyEligible = await manager.isEligibleForIntroOffer(yearly)
        XCTAssertFalse(yearlyEligible)
    }

    func testAskToBuyPendingPurchaseThrowsPurchasePendingError() async throws {
        session.askToBuyEnabled = true

        let manager = makeManager()
        await manager.loadProducts()
        let monthly = try XCTUnwrap(manager.product(for: .monthly))

        do {
            _ = try await manager.purchase(monthly)
            XCTFail("Ask to Buy有効時はpurchasePendingがthrowされるべき")
        } catch SubscriptionError.purchasePending {
            // 期待どおり
        }

        XCTAssertFalse(manager.isProUser)
    }

    // MARK: - Cancellation (auto-renew off, access continues until period end)

    func testDisablingAutoRenewKeepsAccessUntilExpiration() async throws {
        let manager = makeManager()
        await manager.loadProducts()
        let monthly = try XCTUnwrap(manager.product(for: .monthly))
        try await manager.purchase(monthly)
        XCTAssertTrue(manager.isProUser)

        let transaction = try testTransaction(for: .monthly)
        try session.disableAutoRenewForTransaction(identifier: transaction.identifier)
        await waitUntil(condition: { manager.activeProductID == SubscriptionProductID.monthly.rawValue }, manager: manager)

        // 自動更新をオフにしても、現在の契約期間が終わるまではProアクセスを維持する。
        XCTAssertTrue(manager.isProUser)
        XCTAssertEqual(manager.activeProductID, SubscriptionProductID.monthly.rawValue)
    }

    // MARK: - Expiration

    func testExpireSubscriptionRevokesAccess() async throws {
        let manager = makeManager()
        await manager.loadProducts()
        let monthly = try XCTUnwrap(manager.product(for: .monthly))
        try await manager.purchase(monthly)
        XCTAssertTrue(manager.isProUser)

        try session.expireSubscription(productIdentifier: SubscriptionProductID.monthly.rawValue)
        await waitUntil(condition: { !manager.isProUser }, manager: manager)

        XCTAssertFalse(manager.isProUser)
        XCTAssertTrue(manager.purchasedProductIDs.isEmpty)
        XCTAssertNil(manager.activeProductID)
    }

    // MARK: - Refund

    func testRefundedTransactionRevokesAccess() async throws {
        let manager = makeManager()
        await manager.loadProducts()
        let monthly = try XCTUnwrap(manager.product(for: .monthly))
        try await manager.purchase(monthly)
        XCTAssertTrue(manager.isProUser)

        let transaction = try testTransaction(for: .monthly)
        try session.refundTransaction(identifier: transaction.identifier)
        await waitUntil(condition: { !manager.isProUser }, manager: manager)

        XCTAssertFalse(manager.isProUser)
    }

    // MARK: - Restore

    func testRestorePurchasesSyncsEntitlementsOnFreshInstall() async throws {
        let originalManager = makeManager()
        await originalManager.loadProducts()
        let yearly = try XCTUnwrap(originalManager.product(for: .yearly))
        try await originalManager.purchase(yearly)
        XCTAssertTrue(originalManager.isProUser)

        // 再インストール・機種変更を想定し、ローカルキャッシュを持たない新しいマネージャーで復元する。
        let reinstalledManager = makeManager()
        XCTAssertFalse(reinstalledManager.isProUser)

        try await reinstalledManager.restorePurchases()

        XCTAssertTrue(reinstalledManager.isProUser)
        XCTAssertEqual(reinstalledManager.activeProductID, SubscriptionProductID.yearly.rawValue)
    }

    func testRestorePurchasesWithNoPurchaseHistoryLeavesUnsubscribed() async throws {
        let manager = makeManager()

        try await manager.restorePurchases()

        XCTAssertFalse(manager.isProUser)
        XCTAssertTrue(manager.purchasedProductIDs.isEmpty)
    }

    // MARK: - Ad Banner Visibility
    // AdContainerViewは`SubscriptionManager.isAdBannerVisible`を購読して広告バナーの表示・非表示と
    // それに伴うframe(height:)の余白（AdBannerView.height / 0）を切り替える。SwiftUIレンダリングは
    // 検証できないため、その判定ロジック自体（isAdBannerVisible）が購読状態と正しく連動することを検証する。

    func testAdBannerIsVisibleForFreeUser() async throws {
        let manager = makeManager()

        XCTAssertFalse(manager.isProUser)
        XCTAssertTrue(manager.isAdBannerVisible, "無料ユーザーには広告バナーが表示されるべき")
    }

    func testAdBannerBecomesHiddenAfterPurchase() async throws {
        let manager = makeManager()
        await manager.loadProducts()
        let monthly = try XCTUnwrap(manager.product(for: .monthly))

        try await manager.purchase(monthly)

        XCTAssertTrue(manager.isProUser)
        XCTAssertFalse(manager.isAdBannerVisible, "Pro購読済みユーザーには広告バナーが表示されるべきではない")
    }

    func testAdBannerReappearsAfterSubscriptionExpires() async throws {
        let manager = makeManager()
        await manager.loadProducts()
        let monthly = try XCTUnwrap(manager.product(for: .monthly))
        try await manager.purchase(monthly)
        XCTAssertFalse(manager.isAdBannerVisible)

        try session.expireSubscription(productIdentifier: SubscriptionProductID.monthly.rawValue)
        await waitUntil(condition: { !manager.isProUser }, manager: manager)

        XCTAssertFalse(manager.isProUser)
        XCTAssertTrue(manager.isAdBannerVisible, "購読が失効したら広告バナーの表示が復活するべき（スクロール領域の余白も再確保される）")
    }

    // MARK: - Preview Factory
    // SwiftUI PreviewsでProユーザー状態を安全に再現するためのpreview(isProUser:)が、
    // StoreKitへ問い合わせて非同期に値を上書きしないことを検証する。

    func testPreviewFactoryProducesSubscribedStateWithoutOverridingAsync() async throws {
        let manager = SubscriptionManager.preview(isProUser: true)

        XCTAssertTrue(manager.isProUser)
        XCTAssertFalse(manager.isAdBannerVisible)
        XCTAssertEqual(manager.purchasedProductIDs, [SubscriptionProductID.monthly.rawValue])

        // autoRefreshOnInit: false のため、initで起動したTaskによる非同期上書きは発生しないはず。
        // 実際にTaskがスケジュールされていないことを、十分な猶予を与えたうえで確認する。
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(manager.isProUser, "preview(isProUser:)で注入した状態が非同期リフレッシュで上書きされてはならない")
    }

    func testPreviewFactoryProducesUnsubscribedState() {
        let manager = SubscriptionManager.preview(isProUser: false)

        XCTAssertFalse(manager.isProUser)
        XCTAssertTrue(manager.isAdBannerVisible)
        XCTAssertTrue(manager.purchasedProductIDs.isEmpty)
    }
}
