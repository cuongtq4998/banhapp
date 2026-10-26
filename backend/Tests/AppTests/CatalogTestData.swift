import Foundation
import BanhContracts
@testable import App

/// The rows of `backend/db/seed/sample.sql` as the repository would return
/// them, so service and route tests can be compared with the shared fixture
/// `catalog-ok.json`.
enum CatalogTestData {
    static func uuid(_ suffix: String) -> UUID {
        UUID(uuidString: "00000000-0000-4000-8000-0000000000" + suffix)!
    }

    static let snapshot = CatalogSnapshot(
        shop: CatalogShop(
            name: "Tiệm Bánh An Nhiên",
            greeting: "Bánh làm thủ công, giao tận nơi.",
            phoneContact: "+84900000000",
            zaloContact: "84900000000"
        ),
        ordering: OrderingParameters(minQty: 2, leadDays: 2, maxDaysAhead: 30, maxQtyPerCake: 99),
        products: [
            product("11", "banana", "Bánh chuối", "Bánh chuối nướng thơm béo.", 35_000),
            product("12", "mung-bean-pork-fat", "Bánh đậu xanh nhân mỡ", "Đậu xanh nghiền mịn, nhân mỡ.", 45_000),
            product("13", "mung-bean-vegetarian", "Bánh đậu xanh chay", "Đậu xanh nghiền mịn, không nhân mỡ.", 45_000),
            product("14", "mung-bean-egg-yolk-pork-fat", "Bánh đậu xanh trứng mỡ", "Đậu xanh, trứng muối và mỡ.", 55_000)
        ],
        districts: [
            district("21", "Quận 1", 15_000),
            district("22", "Quận 3", 15_000),
            district("23", "Quận 5", 20_000),
            district("24", "Phú Nhuận", 20_000),
            district("25", "Bình Thạnh", 25_000)
        ],
        slots: [
            slot("31", "08:00", "10:00"),
            slot("32", "10:00", "12:00"),
            slot("33", "14:00", "16:00"),
            slot("34", "16:00", "18:00")
        ]
    )

    /// 2026-11-02 at noon, shop time (05:00 UTC), the date of the fixtures.
    static let fixtureClock = FixedWallClock(instant: Date(timeIntervalSince1970: 1_793_595_600))

    private static func product(_ suffix: String, _ slug: String, _ name: String, _ description: String, _ price: Int) -> ProductRecord {
        ProductRecord(id: uuid(suffix), slug: slug, name: name, description: description, priceVND: price, imagePath: "images/\(slug).png")
    }

    private static func district(_ suffix: String, _ name: String, _ fee: Int) -> CatalogDistrict {
        CatalogDistrict(districtID: ResourceID(uuid(suffix)), name: name, deliveryFeeVND: fee)
    }

    private static func slot(_ suffix: String, _ start: String, _ end: String) -> CatalogSlot {
        CatalogSlot(slotID: ResourceID(uuid(suffix)), start: start, end: end)
    }

    /// Versions of the real placeholder images, as the server computes them at start.
    static let assets = AssetURLBuilder(
        baseURL: "",
        versions: AssetVersions.load(fromAssetsDirectory: TestPaths.backend.path + "/assets/")
    )

    static func fixture(_ name: String) throws -> CatalogResponse {
        let data = try Data(contentsOf: TestPaths.contractFixtures.appendingPathComponent(name))
        return try JSONDecoder().decode(CatalogResponse.self, from: data)
    }
}
