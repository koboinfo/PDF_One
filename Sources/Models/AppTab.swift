import Foundation

enum AppTab: CaseIterable {
    case home, files, tools, scanner, settings

    var label: String {
        switch self {
        case .home: return "ホーム"
        case .files: return "ファイル"
        case .tools: return "ツール"
        case .scanner: return "スキャナー"
        case .settings: return "設定"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .files: return "folder"
        case .tools: return "wrench.and.screwdriver"
        case .scanner: return "camera.viewfinder"
        case .settings: return "gearshape"
        }
    }
}
