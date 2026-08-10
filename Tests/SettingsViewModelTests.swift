import XCTest
@testable import PDF_One

@MainActor
final class SettingsViewModelTests: XCTestCase {
    private var sut: SettingsViewModel!
    private var createdFiles: [URL] = []

    override func setUp() {
        super.setUp()
        sut = SettingsViewModel()
        createdFiles = []
    }

    override func tearDown() {
        for url in createdFiles {
            try? FileManager.default.removeItem(at: url)
        }
        createdFiles = []
        sut = nil
        super.tearDown()
    }

    // MARK: - calculateCacheSize

    func testCalculateCacheSizeSumsPDFAndJPGFilesInTemporaryDirectory() async throws {
        let baseline = await currentCacheSize()
        _ = try makeCacheFile(extension: "pdf", byteCount: 1000)
        _ = try makeCacheFile(extension: "jpg", byteCount: 2000)

        await sut.calculateCacheSize()

        XCTAssertEqual(sut.cacheSizeBytes, baseline + 1000 + 2000)
        XCTAssertFalse(sut.isCalculatingCacheSize)
    }

    func testCalculateCacheSizeIgnoresNonCacheExtensions() async throws {
        let baseline = await currentCacheSize()
        _ = try makeCacheFile(extension: "txt", byteCount: 5000)

        await sut.calculateCacheSize()

        XCTAssertEqual(sut.cacheSizeBytes, baseline)
    }

    func testCacheSizeTextFormatsBytesAsFileSize() {
        sut.cacheSizeBytes = 1_048_576

        XCTAssertTrue(sut.cacheSizeText.contains("1"))
    }

    // MARK: - clearCache

    func testClearCacheRemovesCacheFilesAndResetsSize() async throws {
        let cacheFile = try makeCacheFile(extension: "pdf", byteCount: 1000)
        await sut.calculateCacheSize()
        XCTAssertGreaterThan(sut.cacheSizeBytes, 0)

        await sut.clearCache()

        XCTAssertEqual(sut.cacheSizeBytes, 0)
        XCTAssertFalse(sut.isClearingCache)
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheFile.path))
        XCTAssertNotNil(sut.toast)
    }

    func testClearCacheIsNoOpWhenCacheSizeIsZero() async {
        sut.cacheSizeBytes = 0

        await sut.clearCache()

        XCTAssertNil(sut.toast)
        XCTAssertFalse(sut.isClearingCache)
    }

    func testClearCacheDoesNotRemoveFilesWithOtherExtensions() async throws {
        let keptFile = try makeCacheFile(extension: "txt", byteCount: 500)
        let removedFile = try makeCacheFile(extension: "jpg", byteCount: 500)
        await sut.calculateCacheSize()

        await sut.clearCache()

        XCTAssertTrue(FileManager.default.fileExists(atPath: keptFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: removedFile.path))
    }

    // MARK: - Helpers

    private func makeCacheFile(extension ext: String, byteCount: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SettingsViewModelTests-\(UUID().uuidString)")
            .appendingPathExtension(ext)
        try Data(repeating: 0x41, count: byteCount).write(to: url)
        createdFiles.append(url)
        return url
    }

    private func currentCacheSize() async -> Int64 {
        let probe = SettingsViewModel()
        await probe.calculateCacheSize()
        return probe.cacheSizeBytes
    }
}
