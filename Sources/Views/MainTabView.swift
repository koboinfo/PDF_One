import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: AppTab = .tools

    var body: some View {
        content
            .safeAreaInset(edge: .bottom) {
                ModernTabBar(selection: $selectedTab)
                    .padding(.bottom, 8)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .home:
            HomeView()
        case .files:
            FilesView()
        case .tools:
            ToolsView()
        case .scanner:
            ScannerView()
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    MainTabView()
}
