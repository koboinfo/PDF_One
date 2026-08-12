import Foundation

enum AppTab: CaseIterable {
    case home, files, tools, scanner, settings

    var label: String {
        switch self {
        case .home: return String(localized: "ホーム")
        case .files: return String(localized: "ファイル")
        case .tools: return String(localized: "ツール")
        case .scanner: return String(localized: "スキャナー")
        case .settings: return String(localized: "設定")
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
