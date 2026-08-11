import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                systemImage: "house",
                title: "ホーム画面は準備中です"
            )
            .tabBarClearance()
            .withTopAdBanner()
            .navigationTitle("ホーム")
        }
    }
}

#Preview {
    HomeView()
}
