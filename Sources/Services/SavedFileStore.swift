import Foundation

enum SavedFileStoreError: Error {
    case directoryUnavailable(underlying: Error)
    case deletionFailed(underlying: Error)
}

extension SavedFileStoreError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .directoryUnavailable:
            return "保存先フォルダを準備できませんでした。空き容量をご確認ください。"
        case .deletionFailed:
            return "ファイルの削除に失敗しました。"
        }
    }
}

/// 各ツールが生成したPDF/Officeファイルの永続的な保存先。`Documents`配下に置くことでOSやキャッシュ削除による消失を避ける。
/// ファイル種別ごとに`SavedFiles/PDF`・`SavedFiles/Office`のサブディレクトリへ分けて整理する。
enum SavedFileStore {
    enum Category: String {
        case pdf = "PDF"
        case office = "Office"
    }

    static func rootDirectory(fileManager: FileManager = .default) -> URL {
        fileManager
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SavedFiles", isDirectory: true)
    }

    /// カテゴリ別の保存先ディレクトリ。存在しない場合は作成する。
    /// 作成に失敗した場合（空き容量不足やサンドボックス権限の問題等）はエラーを投げる。
    @discardableResult
    static func directory(for category: Category = .pdf, fileManager: FileManager = .default) throws -> URL {
        let directory = rootDirectory(fileManager: fileManager).appendingPathComponent(category.rawValue, isDirectory: true)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw SavedFileStoreError.directoryUnavailable(underlying: error)
        }
        return directory
    }

    /// 保存済みファイルを削除する。他プロセスによる削除等で既に存在しない場合は成功扱いとする。
    static func delete(_ url: URL, fileManager: FileManager = .default) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw SavedFileStoreError.deletionFailed(underlying: error)
        }
    }

    /// 指定URLが属するボリュームの空き容量（バイト）。取得できない場合は`nil`。
    static func availableCapacityBytes(for url: URL, fileManager: FileManager = .default) -> Int64? {
        (try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?
            .volumeAvailableCapacityForImportantUsage
    }
}
