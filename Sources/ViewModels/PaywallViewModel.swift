import Foundation
import StoreKit

@Observable
@MainActor
final class PaywallViewModel {

    private let subscriptionManager: SubscriptionManager

    var selectedProductID: String?
    private(set) var isPurchasing = false
    private(set) var isRestoring = false
    var message: String?
    private(set) var introEligibility: [String: Bool] = [:]

    init(subscriptionManager: SubscriptionManager) {
        self.subscriptionManager = subscriptionManager
    }

    var products: [Product] { subscriptionManager.products }
    var isLoadingProducts: Bool { subscriptionManager.isLoadingProducts }

    var selectedProduct: Product? {
        if let selectedProductID {
            return products.first { $0.id == selectedProductID }
        }
        return products.first
    }

    func onAppear() async {
        if products.isEmpty {
            await subscriptionManager.loadProducts()
        }
        if selectedProductID == nil {
            selectedProductID = products.first { $0.id == SubscriptionProductID.yearly.rawValue }?.id
                ?? products.first?.id
        }
        await refreshIntroEligibility()
    }

    func refreshIntroEligibility() async {
        for product in products {
            introEligibility[product.id] = await subscriptionManager.isEligibleForIntroOffer(product)
        }
    }

    func isEligibleForTrial(_ product: Product) -> Bool {
        introEligibility[product.id] ?? false
    }

    func select(_ product: Product) {
        selectedProductID = product.id
    }

    @discardableResult
    func purchase() async -> Bool {
        guard let product = selectedProduct, !isPurchasing else { return false }

        isPurchasing = true
        message = nil
        defer { isPurchasing = false }

        do {
            return try await subscriptionManager.purchase(product)
        } catch let error as SubscriptionError {
            if case .userCancelled = error {
                return false
            }
            message = error.localizedDescription
            return false
        } catch {
            message = SubscriptionError.failedVerification.localizedDescription
            return false
        }
    }

    func restore() async {
        guard !isRestoring else { return }

        isRestoring = true
        message = nil
        defer { isRestoring = false }

        do {
            try await subscriptionManager.restorePurchases()
            if !subscriptionManager.isProUser {
                message = "復元できる購入が見つかりませんでした。"
            }
        } catch {
            message = SubscriptionError.failedVerification.localizedDescription
        }
    }
}
