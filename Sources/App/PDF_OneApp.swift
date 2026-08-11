import SwiftUI

@main
struct PDF_OneApp: App {
    @State private var subscriptionManager = SubscriptionManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(subscriptionManager)
        }
    }
}
