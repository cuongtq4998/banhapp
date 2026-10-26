import XCTest
import Logging
import BanhContracts
@testable import App

final class CatalogServiceTests: XCTestCase {
    private func makeService(
        snapshot: CatalogSnapshot = CatalogTestData.snapshot,
        assetBase: String = "",
        logger: Logger = Logger(label: "test"),
        clock: FixedWallClock = CatalogTestData.fixtureClock
    ) -> CatalogService {
        CatalogService(
            repository: StubCatalogRepository { _ in snapshot },
            calendar: ShopCalendar(clock: clock),
            assets: AssetURLBuilder(baseURL: assetBase, versions: CatalogTestData.assets.versions),
            logger: logger
        )
    }

    func testBuildsTheSharedOkFixture() async throws {
        let catalog = try await makeService().makeCatalog(shopID: AppConfig.testShopID)
        XCTAssertEqual(catalog, try CatalogTestData.fixture("catalog-ok.json"))
    }

    func testEmptyTablesGiveTheSharedEmptyFixture() async throws {
        let snapshot = CatalogSnapshot(
            shop: CatalogTestData.snapshot.shop,
            ordering: CatalogTestData.snapshot.ordering,
            products: [], districts: [], slots: []
        )
        let catalog = try await makeService(snapshot: snapshot).makeCatalog(shopID: AppConfig.testShopID)
        XCTAssertEqual(catalog, try CatalogTestData.fixture("catalog-empty.json"))
    }

    func testServerDateIsTheShopDateAcrossUTCMidnight() async throws {
        // 18:00 UTC on 1 November is 01:00 on 2 November in Vietnam; two hours earlier it is still 1 November there.
        let late = FixedWallClock(instant: CatalogTestData.fixtureClock.instant.addingTimeInterval(-11 * 3_600))
        let catalog = try await makeService(clock: late).makeCatalog(shopID: AppConfig.testShopID)
        XCTAssertEqual(catalog.serverDate, "2026-11-02")
        let earlier = FixedWallClock(instant: late.instant.addingTimeInterval(-2 * 3_600))
        let earlierCatalog = try await makeService(clock: earlier).makeCatalog(shopID: AppConfig.testShopID)
        XCTAssertEqual(earlierCatalog.serverDate, "2026-11-01")
    }

    func testNoteLengthComesFromTheInputBound() async throws {
        let catalog = try await makeService().makeCatalog(shopID: AppConfig.testShopID)
        XCTAssertEqual(catalog.settings.noteMaxLength, InputLimits.noteMaxLength)
    }

    func testImageURLUsesTheConfiguredBase() async throws {
        let catalog = try await makeService(assetBase: "https://cdn.example").makeCatalog(shopID: AppConfig.testShopID)
        XCTAssertEqual(catalog.products.first?.imageURL, "https://cdn.example/assets/images/banana.png?v=a547ade3")
    }

    func testImagesWithoutAFileHaveNoVersionAndAreWarnedAbout() async throws {
        let capture = LogCapture()
        let service = CatalogService(
            repository: StubCatalogRepository { _ in CatalogTestData.snapshot },
            calendar: ShopCalendar(clock: CatalogTestData.fixtureClock),
            assets: AssetURLBuilder(baseURL: "", versions: AssetVersions(hashes: ["images/banana.png": "abcd1234"])),
            logger: capture.makeLogger()
        )
        let catalog = try await service.makeCatalog(shopID: AppConfig.testShopID)
        XCTAssertEqual(catalog.products[0].imageURL, "/assets/images/banana.png?v=abcd1234")
        XCTAssertEqual(catalog.products[1].imageURL, "/assets/images/mung-bean-pork-fat.png")
        let warnings = capture.lines.filter { $0.message.contains("image file not found") }
        XCTAssertEqual(warnings.count, 3)
    }

    func testRepositoryErrorsPassThrough() async {
        let service = CatalogService(
            repository: StubCatalogRepository { _ in throw APIError(.serviceUnavailable) },
            calendar: ShopCalendar(clock: CatalogTestData.fixtureClock),
            assets: AssetURLBuilder(baseURL: ""),
            logger: Logger(label: "test")
        )
        do {
            _ = try await service.makeCatalog(shopID: AppConfig.testShopID)
            XCTFail("expected an error")
        } catch let error as APIError {
            XCTAssertEqual(error.code, .serviceUnavailable)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testTheShopIDIsPassedToTheRepository() async throws {
        let seen = LockedBox<UUID?>(nil)
        let service = CatalogService(
            repository: StubCatalogRepository { id in
                seen.set(id)
                return CatalogTestData.snapshot
            },
            calendar: ShopCalendar(clock: CatalogTestData.fixtureClock),
            assets: AssetURLBuilder(baseURL: ""),
            logger: Logger(label: "test")
        )
        _ = try await service.makeCatalog(shopID: AppConfig.testShopID)
        XCTAssertEqual(seen.value, AppConfig.testShopID)
    }
}
