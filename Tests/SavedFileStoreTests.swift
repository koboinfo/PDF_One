import XCTest
@testable import PDF_One

final class SavedFileStoreTests: XCTestCase {
    private var fileManager: FileManager!
    private var createdURLs: [URL] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        fileManager = .default
        createdURLs = []
    }

    override func tearDownWithError() throws {
        for url in createdURLs {
            try? fileManager.removeItem(at: url)
        }
        try? fileManager.removeItem(at: SavedFileStore.rootDirectory(fileManager: fileManager))
        createdURLs = []
        fileManager = nil
        try super.tearDownWithError()
    }

    // MARK: - directory(for:)

    func testDirectoryCreatesPDFSubdirectoryUnderDocuments() throws {
        let directory = try SavedFileStore.directory(for: .pdf, fileManager: fileManager)

        var isDirectory: ObjCBool = false
        XCTAssertTrue(fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertEqual(directory.lastPathComponent, "PDF")
        XCTAssertEqual(directory.deletingLastPathComponent().lastPathComponent, "SavedFiles")
    }

    func testDirectorySeparatesPDFAndOfficeCategories() throws {
        let pdfDirectory = try SavedFileStore.directory(for: .pdf, fileManager: fileManager)
        let officeDirectory = try SavedFileStore.directory(for: .office, fileManager: fileManager)

        XCTAssertNotEqual(pdfDirectory, officeDirectory)
        XCTAssertEqual(officeDirectory.lastPathComponent, "Office")
    }

    func testDirectoryIsIdempotentWhenCalledRepeatedly() throws {
        let first = try SavedFileStore.directory(for: .pdf, fileManager: fileManager)
        let second = try SavedFileStore.directory(for: .pdf, fileManager: fileManager)

        XCTAssertEqual(first, second)
        XCTAssertTrue(fileManager.fileExists(atPath: first.path))
    }

    // MARK: - save / read round trip

    func testFileWrittenIntoDirectoryIsReadableBack() throws {
        let directory = try SavedFileStore.directory(for: .pdf, fileManager: fileManager)
        let fileURL = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
        createdURLs.append(fileURL)
        let payload = Data("saved-file-store-test".utf8)

        try payload.write(to: fileURL)
        let readBack = try Data(contentsOf: fileURL)

        XCTAssertEqual(readBack, payload)
    }

    // MARK: - delete

    func testDeleteRemovesExistingFile() throws {
        let directory = try SavedFileStore.directory(for: .pdf, fileManager: fileManager)
        let fileURL = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
        try Data("to-delete".utf8).write(to: fileURL)
        XCTAssertTrue(fileManager.fileExists(atPath: fileURL.path))

        try SavedFileStore.delete(fileURL, fileManager: fileManager)

        XCTAssertFalse(fileManager.fileExists(atPath: fileURL.path))
    }

    func testDeleteOfAlreadyMissingFileDoesNotThrow() throws {
        let directory = try SavedFileStore.directory(for: .pdf, fileManager: fileManager)
        let missingURL = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")

        XCTAssertNoThrow(try SavedFileStore.delete(missingURL, fileManager: fileManager))
    }

    func testDeletePropagatesUnderlyingFailureAsDeletionFailed() throws {
        let restrictedFileManager = RestrictedRemovalFileManager()
        let directory = try SavedFileStore.directory(for: .pdf, fileManager: fileManager)
        let fileURL = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
        try Data("undeletable".utf8).write(to: fileURL)
        createdURLs.append(fileURL)

        XCTAssertThrowsError(try SavedFileStore.delete(fileURL, fileManager: restrictedFileManager)) { error in
            guard case SavedFileStoreError.deletionFailed = error else {
                XCTFail("Expected deletionFailed, got \(error)")
                return
            }
        }
    }

    // MARK: - availableCapacityBytes

    func testAvailableCapacityBytesReturnsPositiveValueForDocumentsVolume() throws {
        let directory = try SavedFileStore.directory(for: .pdf, fileManager: fileManager)

        let capacity = SavedFileStore.availableCapacityBytes(for: directory, fileManager: fileManager)

        XCTAssertNotNil(capacity)
        XCTAssertGreaterThan(capacity ?? 0, 0)
    }
}

/// `removeItem`が常に失敗する`FileManager`スタブ。`SavedFileStore.delete`のエラー伝播を検証するために使う。
private final class RestrictedRemovalFileManager: FileManager {
    override func removeItem(at URL: URL) throws {
        throw NSError(domain: "RestrictedRemovalFileManager", code: -1)
    }
}
