import XCTest
@testable import PDF_One

@MainActor
final class FilesViewModelTests: XCTestCase {
    private var sut: FilesViewModel!
    private var fileManager: FileManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fileManager = .default
        sut = FilesViewModel(fileManager: fileManager)
        try? fileManager.removeItem(at: SavedFileStore.rootDirectory(fileManager: fileManager))
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: SavedFileStore.rootDirectory(fileManager: fileManager))
        sut = nil
        fileManager = nil
        try super.tearDownWithError()
    }

    // MARK: - loadFiles

    func testLoadFilesFindsPDFFilesInPDFCategory() async throws {
        _ = try makeSavedFile(category: .pdf, name: "report.pdf", byteCount: 1000)

        await sut.loadFiles()

        XCTAssertEqual(sut.files.count, 1)
        XCTAssertEqual(sut.files.first?.displayName, "report")
    }

    func testLoadFilesFindsOfficeFilesAcrossCategories() async throws {
        _ = try makeSavedFile(category: .pdf, name: "converted.pdf", byteCount: 500)
        _ = try makeSavedFile(category: .office, name: "converted.docx", byteCount: 500)
        _ = try makeSavedFile(category: .office, name: "sheet.xlsx", byteCount: 500)

        await sut.loadFiles()

        XCTAssertEqual(sut.files.count, 3)
        XCTAssertTrue(sut.files.contains { $0.url.pathExtension == "docx" })
        XCTAssertTrue(sut.files.contains { $0.url.pathExtension == "xlsx" })
    }

    func testLoadFilesFindsFilesNestedInSubdirectories() async throws {
        let directory = try SavedFileStore.directory(for: .pdf, fileManager: fileManager)
        let subdirectory = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: subdirectory, withIntermediateDirectories: true)
        try Data("split-1".utf8).write(to: subdirectory.appendingPathComponent("split_1.pdf"))

        await sut.loadFiles()

        XCTAssertEqual(sut.files.count, 1)
    }

    func testLoadFilesIgnoresUnrelatedExtensions() async throws {
        _ = try makeSavedFile(category: .pdf, name: "note.txt", byteCount: 100)

        await sut.loadFiles()

        XCTAssertTrue(sut.files.isEmpty)
    }

    // MARK: - displayedFiles: search & sort

    func testDisplayedFilesFiltersBySearchText() async throws {
        _ = try makeSavedFile(category: .pdf, name: "invoice.pdf", byteCount: 100)
        _ = try makeSavedFile(category: .pdf, name: "receipt.pdf", byteCount: 100)
        await sut.loadFiles()

        sut.searchText = "invoice"

        XCTAssertEqual(sut.displayedFiles.map(\.displayName), ["invoice"])
    }

    func testDisplayedFilesSortsBySizeDescending() async throws {
        _ = try makeSavedFile(category: .pdf, name: "small.pdf", byteCount: 100)
        _ = try makeSavedFile(category: .pdf, name: "large.pdf", byteCount: 5000)
        await sut.loadFiles()

        sut.sortOption = .sizeDescending

        XCTAssertEqual(sut.displayedFiles.map(\.displayName), ["large", "small"])
    }

    // MARK: - delete

    func testDeleteRemovesFileFromDiskAndList() async throws {
        let url = try makeSavedFile(category: .pdf, name: "removable.pdf", byteCount: 100)
        await sut.loadFiles()
        let file = try XCTUnwrap(sut.files.first)

        sut.delete(file)

        XCTAssertTrue(sut.files.isEmpty)
        XCTAssertFalse(fileManager.fileExists(atPath: url.path))
    }

    func testDeleteAtOffsetsShowsSuccessToast() async throws {
        _ = try makeSavedFile(category: .pdf, name: "a.pdf", byteCount: 100)
        await sut.loadFiles()

        sut.delete(at: IndexSet(integer: 0))

        XCTAssertEqual(sut.toast?.style, .success)
    }

    func testDeleteOfAlreadyMissingFileTreatsAsSuccessAndRemovesFromList() async throws {
        let url = try makeSavedFile(category: .pdf, name: "vanishing.pdf", byteCount: 100)
        await sut.loadFiles()
        let file = try XCTUnwrap(sut.files.first)
        // ファイルを外部プロセス（他ツールの再生成等）で先に消してしまった状況を模す。
        try fileManager.removeItem(at: url)

        let succeeded = sut.delete(file)

        XCTAssertTrue(succeeded)
        XCTAssertTrue(sut.files.isEmpty)
    }

    func testDeleteFailurePreservesFileInListAndShowsErrorToast() async throws {
        let restrictedFileManager = RestrictedRemovalFileManager()
        let restrictedSUT = FilesViewModel(fileManager: restrictedFileManager)
        let url = try makeSavedFile(category: .pdf, name: "locked.pdf", byteCount: 100)
        await restrictedSUT.loadFiles()
        let file = try XCTUnwrap(restrictedSUT.files.first)

        let succeeded = restrictedSUT.delete(file)

        XCTAssertFalse(succeeded)
        XCTAssertEqual(restrictedSUT.files.count, 1)
        XCTAssertEqual(restrictedSUT.toast?.style, .error)
        try fileManager.removeItem(at: url)
    }

    // MARK: - Helpers

    @discardableResult
    private func makeSavedFile(category: SavedFileStore.Category, name: String, byteCount: Int) throws -> URL {
        let directory = try SavedFileStore.directory(for: category, fileManager: fileManager)
        let url = directory.appendingPathComponent(name)
        try Data(repeating: 0x41, count: byteCount).write(to: url)
        return url
    }
}

/// `removeItem`が常に失敗する`FileManager`スタブ。削除失敗時にリストからファイルが消えないことを検証するために使う。
private final class RestrictedRemovalFileManager: FileManager {
    override func removeItem(at URL: URL) throws {
        throw NSError(domain: "RestrictedRemovalFileManager", code: -1)
    }
}
