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
        session = try SKTestSession(configurationFileNamed: "Subscriptions")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
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
        XCTAssertTrue(manager.isSubscribed)
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

        XCTAssertTrue(manager.isSubscribed)
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

        XCTAssertFalse(manager.isSubscribed)
    }

    // MARK: - Cancellation (auto-renew off, access continues until period end)

    func testDisablingAutoRenewKeepsAccessUntilExpiration() async throws {
        let manager = makeManager()
        await manager.loadProducts()
        let monthly = try XCTUnwrap(manager.product(for: .monthly))
        try await manager.purchase(monthly)
        XCTAssertTrue(manager.isSubscribed)

        let transaction = try testTransaction(for: .monthly)
        try session.disableAutoRenewForTransaction(identifier: transaction.identifier)
        await manager.refreshEntitlements()

        // 自動更新をオフにしても、現在の契約期間が終わるまではProアクセスを維持する。
        XCTAssertTrue(manager.isSubscribed)
        XCTAssertEqual(manager.activeProductID, SubscriptionProductID.monthly.rawValue)
    }

    // MARK: - Expiration

    func testExpireSubscriptionRevokesAccess() async throws {
        let manager = makeManager()
        await manager.loadProducts()
        let monthly = try XCTUnwrap(manager.product(for: .monthly))
        try await manager.purchase(monthly)
        XCTAssertTrue(manager.isSubscribed)

        try session.expireSubscription(productIdentifier: SubscriptionProductID.monthly.rawValue)
        await manager.refreshEntitlements()

        XCTAssertFalse(manager.isSubscribed)
        XCTAssertTrue(manager.purchasedProductIDs.isEmpty)
        XCTAssertNil(manager.activeProductID)
    }

    // MARK: - Refund

    func testRefundedTransactionRevokesAccess() async throws {
        let manager = makeManager()
        await manager.loadProducts()
        let monthly = try XCTUnwrap(manager.product(for: .monthly))
        try await manager.purchase(monthly)
        XCTAssertTrue(manager.isSubscribed)

        let transaction = try testTransaction(for: .monthly)
        try session.refundTransaction(identifier: transaction.identifier)
        await manager.refreshEntitlements()

        XCTAssertFalse(manager.isSubscribed)
    }

    // MARK: - Restore

    func testRestorePurchasesSyncsEntitlementsOnFreshInstall() async throws {
        let originalManager = makeManager()
        await originalManager.loadProducts()
        let yearly = try XCTUnwrap(originalManager.product(for: .yearly))
        try await originalManager.purchase(yearly)
        XCTAssertTrue(originalManager.isSubscribed)

        // 再インストール・機種変更を想定し、ローカルキャッシュを持たない新しいマネージャーで復元する。
        let reinstalledManager = makeManager()
        XCTAssertFalse(reinstalledManager.isSubscribed)

        try await reinstalledManager.restorePurchases()

        XCTAssertTrue(reinstalledManager.isSubscribed)
        XCTAssertEqual(reinstalledManager.activeProductID, SubscriptionProductID.yearly.rawValue)
    }

    func testRestorePurchasesWithNoPurchaseHistoryLeavesUnsubscribed() async throws {
        let manager = makeManager()

        try await manager.restorePurchases()

        XCTAssertFalse(manager.isSubscribed)
        XCTAssertTrue(manager.purchasedProductIDs.isEmpty)
    }
}
