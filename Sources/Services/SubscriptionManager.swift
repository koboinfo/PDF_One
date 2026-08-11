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
    private(set) var isProUser: Bool

    /// 現在有効なプランのプロダクトID（複数同時購読は想定しないため単一値）。設定画面での表示用。
    private(set) var activeProductID: String?
    /// 現在有効なプランの更新日/失効日。トライアル中もこの日付が「トライアル終了日」を兼ねる。
    private(set) var activeExpirationDate: Date?
    /// 現在有効なプランが無料トライアル中かどうか。
    private(set) var isInIntroductoryOffer: Bool = false

    private let userDefaults: UserDefaults
    private static let isProCacheKey = "com.pdfone.subscription.isProCache"

    /// - Parameter autoRefreshOnInit: `false`にすると起動時のプロダクト取得/エンタイトルメント再計算を行わない。
    ///   StoreKitへの実問い合わせができないPreview環境で、注入した購読状態が非同期に上書きされるのを防ぐためのもの。
    init(userDefaults: UserDefaults = .standard, autoRefreshOnInit: Bool = true) {
        self.userDefaults = userDefaults
        isProUser = userDefaults.bool(forKey: Self.isProCacheKey)

        _ = listenForTransactionUpdates()

        guard autoRefreshOnInit else { return }

        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    /// 指定プロダクトが購入画面時点でまだ無料トライアルの対象かどうか（過去に同一グループを購読したことがあると`false`になる）。
    func isEligibleForIntroOffer(_ product: Product) async -> Bool {
        guard let subscription = product.subscription else { return false }
        guard subscription.introductoryOffer != nil else { return false }
        return await subscription.isEligibleForIntroOffer
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
        var latestExpirationDate: Date?
        var latestProductID: String?
        var latestIsIntroductory = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.checkVerified(result) else { continue }
            guard transaction.revocationDate == nil else { continue }

            activeProductIDs.insert(transaction.productID)

            // 複数エンタイトルメントが返るケース（プラン切り替え直後等）では、失効日が最も新しいものを「現在のプラン」とみなす。
            if latestExpirationDate == nil || (transaction.expirationDate ?? .distantFuture) > (latestExpirationDate ?? .distantPast) {
                latestExpirationDate = transaction.expirationDate
                latestProductID = transaction.productID
                latestIsIntroductory = transaction.offerType == .introductory
            }
        }

        purchasedProductIDs = activeProductIDs
        isProUser = !activeProductIDs.isEmpty
        activeProductID = latestProductID
        activeExpirationDate = latestExpirationDate
        isInIntroductoryOffer = latestIsIntroductory
        userDefaults.set(isProUser, forKey: Self.isProCacheKey)
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

    func product(for id: SubscriptionProductID) -> Product? {
        products.first { $0.id == id.rawValue }
    }

    /// 広告バナーを表示すべきかどうか。無料ユーザーにのみ表示する。
    var isAdBannerVisible: Bool { !isProUser }

    private nonisolated static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

#if DEBUG
extension SubscriptionManager {
    /// SwiftUI Previews専用。StoreKitへ問い合わせず、指定した購読状態を確定させたインスタンスを返す。
    static func preview(isProUser: Bool) -> SubscriptionManager {
        let defaults = UserDefaults(suiteName: "preview.subscription.\(UUID().uuidString)")!
        let manager = SubscriptionManager(userDefaults: defaults, autoRefreshOnInit: false)
        manager.purchasedProductIDs = isProUser ? [SubscriptionProductID.monthly.rawValue] : []
        manager.isProUser = isProUser
        return manager
    }
}
#endif
