import Foundation

@Observable
@MainActor
final class FilesViewModel {

    enum SortOption: CaseIterable, Hashable {
        case dateDescending
        case nameAscending
        case sizeDescending

        var label: String {
            switch self {
            case .dateDescending: return "更新日（新しい順）"
            case .nameAscending: return "名前順"
            case .sizeDescending: return "サイズ（大きい順）"
            }
        }
    }

    var files: [SavedFile] = []
    var searchText: String = ""
    var sortOption: SortOption = .dateDescending
    var isLoading: Bool = false
    var toast: ToastData?

    private let pdfService: PDFServiceProtocol
    private let fileManager: FileManager

    init(pdfService: PDFServiceProtocol = PDFService(), fileManager: FileManager = .default) {
        self.pdfService = pdfService
        self.fileManager = fileManager
    }

    var displayedFiles: [SavedFile] {
        let filtered = searchText.isEmpty
            ? files
            : files.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }

        switch sortOption {
        case .dateDescending:
            return filtered.sorted { $0.modifiedDate > $1.modifiedDate }
        case .nameAscending:
            return filtered.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        case .sizeDescending:
            return filtered.sorted { $0.sizeBytes > $1.sizeBytes }
        }
    }

    private static let savedFileExtensions: Set<String> = ["pdf", "docx", "xlsx", "pptx"]

    func loadFiles() async {
        isLoading = true

        let root = SavedFileStore.rootDirectory(fileManager: fileManager)
        let urls = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )?.compactMap { $0 as? URL }.filter { Self.savedFileExtensions.contains($0.pathExtension.lowercased()) } ?? []

        files = urls.map { url in
            let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let pageCount = try? pdfService.inspect(url: url).pageCount
            return SavedFile(
                url: url,
                sizeBytes: Int64(resourceValues?.fileSize ?? 0),
                modifiedDate: resourceValues?.contentModificationDate ?? Date.distantPast,
                pageCount: pageCount
            )
        }

        isLoading = false
    }

    @discardableResult
    func delete(_ file: SavedFile) -> Bool {
        do {
            try SavedFileStore.delete(file.url, fileManager: fileManager)
            files.removeAll { $0.id == file.id }
            return true
        } catch {
            toast = ToastData(style: .error, message: error.localizedDescription)
            return false
        }
    }

    func delete(at offsets: IndexSet) {
        let targets = offsets.map { displayedFiles[$0] }
        let allSucceeded = targets.map(delete).allSatisfy { $0 }
        if allSucceeded {
            toast = ToastData(style: .success, message: "ファイルを削除しました")
        }
    }
}
