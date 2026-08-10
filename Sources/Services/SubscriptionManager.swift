import Foundation
import StoreKit

enum SubscriptionProductID: String, CaseIterable {
    case monthly = "com.pdfone.pro.monthly"
    case yearly = "com.pdfone.pro.yearly"

    static var all: [String] { allCases.map(\.rawValue) }
}

enum SubscriptionError: Error {
    case failedVerification
    case userCancelled
    case purchasePending
    case productsUnavailable
}

extension SubscriptionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "購入情報を確認できませんでした。時間をおいて再度お試しください。"
        case .userCancelled:
            return "購入がキャンセルされました。"
        case .purchasePending:
            return "購入が保留中です。承認が完了すると自動的に反映されます。"
        case .productsUnavailable:
            return "プランを取得できませんでした。通信環境をご確認のうえ再度お試しください。"
        }
    }
}

/// StoreKit 2ベースの課金マネージャー。プロダクト取得・購入・復元・購読状態の反映を担う。
/// `Transaction.updates`を継続監視し、App Store側での契約変更（更新・解約・返金）を即座に反映する。
@Observable
@MainActor
final class SubscriptionManager {

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isLoadingProducts = false
    var purchaseError: String?

    /// StoreKitへの問い合わせ前でも直近の購読状態を即座にUIへ反映するためのローカルキャッシュ。
    /// 正としては扱わず、起動時・Transaction更新時に必ずStoreKitの実体（Transaction.currentEntitlements）で上書きする。
    private(set) var isSubscribed: Bool

    private let userDefaults: UserDefaults
    private static let isProCacheKey = "com.pdfone.subscription.isProCache"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        isSubscribed = userDefaults.bool(forKey: Self.isProCacheKey)

        _ = listenForTransactionUpdates()

        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            products = try await Product.products(for: SubscriptionProductID.all)
                .sorted { $0.price < $1.price }
        } catch {
            purchaseError = SubscriptionError.productsUnavailable.localizedDescription
        }
    }

    @discardableResult
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            await refreshEntitlements()
            await transaction.finish()
            return true

        case .userCancelled:
            throw SubscriptionError.userCancelled

        case .pending:
            throw SubscriptionError.purchasePending

        @unknown default:
            throw SubscriptionError.failedVerification
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    /// `Transaction.currentEntitlements`を正として購読状態を再計算し、ローカルキャッシュを更新する。
    func refreshEntitlements() async {
        var activeProductIDs: Set<String> = []

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.checkVerified(result) else { continue }
            if transaction.revocationDate == nil {
                activeProductIDs.insert(transaction.productID)
            }
        }

        purchasedProductIDs = activeProductIDs
        isSubscribed = !activeProductIDs.isEmpty
        userDefaults.set(isSubscribed, forKey: Self.isProCacheKey)
    }

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let transaction = try? Self.checkVerified(result) else { continue }
                await self?.refreshEntitlements()
                await transaction.finish()
            }
        }
    }

    private nonisolated static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}
