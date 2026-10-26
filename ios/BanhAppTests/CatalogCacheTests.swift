import XCTest
@testable import BanhApp

final class CatalogCacheTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: "banh-cache-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testAgeRuleIsSevenDaysInclusive() throws {
        let fetched = Date(timeIntervalSince1970: 1_000_000)
        let entry = CachedCatalog(catalog: try CatalogTestData.okCatalog(), etag: nil, fetchedAt: fetched)
        XCTAssertEqual(CachedCatalog.maxAge, 7 * 24 * 60 * 60)
        XCTAssertTrue(entry.isUsable(at: fetched.addingTimeInterval(CachedCatalog.maxAge)))
        XCTAssertFalse(entry.isUsable(at: fetched.addingTimeInterval(CachedCatalog.maxAge + 1)))
    }

    func testFileCacheReturnsWhatWasWritten() async throws {
        let cache = FileCatalogCache(fileURL: directory.appending(path: "cache.json"))
        let empty = await cache.read()
        XCTAssertNil(empty)

        let entry = CachedCatalog(
            catalog: try CatalogTestData.okCatalog(), etag: "\"abc\"", fetchedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        await cache.write(entry)

        let stored = await cache.read()
        XCTAssertEqual(stored, entry)
    }

    func testADamagedFileReadsAsAbsent() async throws {
        let file = directory.appending(path: "cache.json")
        try Data("not json".utf8).write(to: file)
        let stored = await FileCatalogCache(fileURL: file).read()
        XCTAssertNil(stored)
    }

    func testAWriteReplacesTheEarlierCopy() async throws {
        let cache = FileCatalogCache(fileURL: directory.appending(path: "cache.json"))
        let catalog = try CatalogTestData.okCatalog()
        await cache.write(CachedCatalog(catalog: catalog, etag: "\"one\"", fetchedAt: Date(timeIntervalSince1970: 1)))
        await cache.write(CachedCatalog(catalog: catalog, etag: "\"two\"", fetchedAt: Date(timeIntervalSince1970: 2)))
        let stored = await cache.read()
        XCTAssertEqual(stored?.etag, "\"two\"")
    }
}
