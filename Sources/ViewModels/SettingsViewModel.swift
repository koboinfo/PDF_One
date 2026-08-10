import Foundation

@Observable
final class SettingsViewModel {

    var cacheSizeBytes: Int64 = 0
    var isCalculatingCacheSize: Bool = false
    var isClearingCache: Bool = false
    var toast: ToastData?

    private let fileManager: FileManager
    private static let cacheFileExtensions: Set<String> = ["pdf", "jpg"]

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
        if let contents = try? fileManager.contentsOfDirectory(
            at: temporaryDirectory,
            includingPropertiesForKeys: nil
        ) {
            for fileURL in contents where Self.cacheFileExtensions.contains(fileURL.pathExtension.lowercased()) {
                try? fileManager.removeItem(at: fileURL)
            }
        }

        cacheSizeBytes = Self.cacheFilesSize(in: temporaryDirectory, fileManager: fileManager)
        isClearingCache = false
        toast = ToastData(style: .success, message: "キャッシュを削除しました")
    }

    private static func cacheFilesSize(in directory: URL, fileManager: FileManager) -> Int64 {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        return contents
            .filter { cacheFileExtensions.contains($0.pathExtension.lowercased()) }
            .reduce(Int64(0)) { total, fileURL in
                let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                return total + Int64(size)
            }
    }
}
