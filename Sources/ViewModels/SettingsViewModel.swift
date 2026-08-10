import Foundation

@Observable
@MainActor
final class SettingsViewModel {

    var cacheSizeBytes: Int64 = 0
    var isCalculatingCacheSize: Bool = false
    var isClearingCache: Bool = false
    var toast: ToastData?

    private let fileManager: FileManager
    private static let cacheFileExtensions: Set<String> = ["pdf", "jpg", "txt"]

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    var cacheSizeText: String {
        ByteCountFormatter.string(fromByteCount: cacheSizeBytes, countStyle: .file)
    }

    var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "バージョン \(version) (\(build))"
    }

    func calculateCacheSize() async {
        isCalculatingCacheSize = true
        cacheSizeBytes = Self.cacheFilesSize(
            in: fileManager.temporaryDirectory,
            fileManager: fileManager
        )
        isCalculatingCacheSize = false
    }

    func clearCache() async {
        guard cacheSizeBytes > 0, !isClearingCache else { return }

        isClearingCache = true

        let temporaryDirectory = fileManager.temporaryDirectory
        for fileURL in Self.cacheFileURLs(in: temporaryDirectory, fileManager: fileManager) {
            try? fileManager.removeItem(at: fileURL)
        }

        cacheSizeBytes = Self.cacheFilesSize(in: temporaryDirectory, fileManager: fileManager)
        isClearingCache = false
        toast = ToastData(style: .success, message: "キャッシュを削除しました")
    }

    /// `temporaryDirectory`配下をサブディレクトリも含めて再帰的に走査し、対象拡張子のファイルURLを返す。
    /// スキャン画像やページ書き出しなど、ツールごとのUUIDサブディレクトリに置かれたキャッシュも捕捉するため。
    private static func cacheFileURLs(in directory: URL, fileManager: FileManager) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return enumerator.compactMap { $0 as? URL }.filter { cacheFileExtensions.contains($0.pathExtension.lowercased()) }
    }

    private static func cacheFilesSize(in directory: URL, fileManager: FileManager) -> Int64 {
        cacheFileURLs(in: directory, fileManager: fileManager).reduce(Int64(0)) { total, fileURL in
            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + Int64(size)
        }
    }
}
