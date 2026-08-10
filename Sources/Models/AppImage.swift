import Foundation

/// ローカル端末の画像とCloudinary等のリモートURL画像を、画像を扱うViewModelが区別なく扱えるようにする統一モデル。
struct AppImage: Identifiable, Hashable {
    enum Source: Hashable {
        case local(URL)
        case remote(URL)
    }

    let id: UUID
    let source: Source

    init(id: UUID = UUID(), source: Source) {
        self.id = id
        self.source = source
    }

    static func local(_ url: URL) -> AppImage {
        AppImage(source: .local(url))
    }

    static func remote(_ url: URL) -> AppImage {
        AppImage(source: .remote(url))
    }

    /// サムネイル表示に使えるURL（ローカルファイルパス、またはCloudinaryなどのリモートURL）。
    var displayURL: URL {
        switch source {
        case .local(let url), .remote(let url):
            return url
        }
    }

    var isRemote: Bool {
        if case .remote = source { return true }
        return false
    }
}
