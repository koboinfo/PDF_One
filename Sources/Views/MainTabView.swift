import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: AppTab = .tools

    var body: some View {
        // 上部広告はここでは適用しない。ここに置くと`NavigationStack`の外側になり、
        // プッシュされるツール詳細画面（`BaseToolView`）にも広告枠がかかる。ツール詳細は
        // ナビゲーションバーを隠して独自ヘッダー（戻る/タイトル/ヘルプ）を描くため、
        // そのヘッダーが広告の裏に隠れて戻れなくなる。各タブのルートが`NavigationStack`の
        // 内側で1枚だけ出す（下部にも出さないので、広告は常に画面上部の1枚に統一される）。
        content
            .safeAreaInset(edge: .bottom) {
                ModernTabBar(selection: $selectedTab)
                    .padding(.bottom, LayoutConstants.tabBarBottomPadding)
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
        .environment(SubscriptionManager())
}
