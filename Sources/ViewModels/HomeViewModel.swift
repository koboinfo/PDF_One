import SwiftUI

/// ホーム画面のクイックアクション/ツール詳細への遷移先。
/// `Models/ToolItem.swift`の`ToolRoute`とは別に持つことで、ホームは無料ツール数点＋スキャンのみを
/// 扱う軽量な構成にとどめ、`ToolsView`側の型・switchには影響を与えない。
enum HomeDestination: Hashable {
    case merge, imageToPDF, compress, scanner
}

struct HomeQuickAction: Identifiable {
    let title: String
    let systemImage: String
    let tint: Color
    let destination: HomeDestination

    var id: HomeDestination { destination }
}

@Observable
@MainActor
final class HomeViewModel {

    let quickActions: [HomeQuickAction]
    var recentFiles: [SavedFile] = []
    var isLoadingRecentFiles = false
    var path: [HomeDestination] = []

    private let filesViewModel: FilesViewModel
    private static let recentFilesLimit = 5

    init(filesViewModel: FilesViewModel? = nil) {
        self.filesViewModel = filesViewModel ?? FilesViewModel()
        quickActions = [
            HomeQuickAction(
                title: String(localized: "スキャン"),
                systemImage: "doc.viewfinder",
                tint: Color(hue: 0.58, saturation: 0.28, brightness: 0.55),
                destination: .scanner
            ),
            HomeQuickAction(
                title: String(localized: "PDF結合"),
                systemImage: ToolIconType.merge.systemImage,
                tint: ToolIconType.merge.tint,
                destination: .merge
            ),
            HomeQuickAction(
                title: String(localized: "画像→PDF"),
                systemImage: ToolIconType.imageToPDF.systemImage,
                tint: ToolIconType.imageToPDF.tint,
                destination: .imageToPDF
            ),
            HomeQuickAction(
                title: String(localized: "圧縮"),
                systemImage: ToolIconType.compress.systemImage,
                tint: ToolIconType.compress.tint,
                destination: .compress
            )
        ]
    }

    func loadRecentFiles() async {
        isLoadingRecentFiles = true
        await filesViewModel.loadFiles()
        recentFiles = Array(filesViewModel.displayedFiles.prefix(Self.recentFilesLimit))
        isLoadingRecentFiles = false
    }
}
