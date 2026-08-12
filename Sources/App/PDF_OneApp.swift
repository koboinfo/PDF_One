import GoogleMobileAds
import SwiftUI

@main
struct PDF_OneApp: App {
    @State private var subscriptionManager = SubscriptionManager()
    @State private var authService = AuthService()

    init() {
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        let subscriptionManager = subscriptionManager
        AdMobInterstitialManager.shared.configure(isProUserProvider: { subscriptionManager.isProUser })
        AdMobInterstitialManager.shared.preloadAd()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(subscriptionManager)
                .environment(authService)
        }
    }
}
