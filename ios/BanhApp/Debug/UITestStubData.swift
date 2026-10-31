#if DEBUG
import BanhContracts
import Foundation

/// The fake shop of the UI tests; mirrors `contracts/fixtures/catalog-ok.json`.
enum UITestStubData {
    static func id(_ suffix: Int) -> ResourceID {
        ResourceID(UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", suffix))!)
    }

    static let catalog = CatalogResponse(
        serverDate: "2026-11-02",
        shop: CatalogShop(
            name: "Tiệm Bánh An Nhiên",
            greeting: "Bánh làm thủ công, giao tận nơi.",
            phoneContact: "+84900000000",
            zaloContact: "84900000000"
        ),
        settings: CatalogSettings(minQty: 2, leadDays: 2, maxDaysAhead: 30, maxQtyPerCake: 99, noteMaxLength: 200),
        products: [
            CatalogProduct(productID: id(11), slug: "banana", name: "Bánh chuối",
                           description: "Bánh chuối nướng thơm béo.", priceVND: 35_000,
                           imageURL: "/assets/images/banana.png?v=a547ade3"),
            CatalogProduct(productID: id(12), slug: "mung-bean-pork-fat", name: "Bánh đậu xanh nhân mỡ",
                           description: "Đậu xanh nghiền mịn, nhân mỡ.", priceVND: 45_000,
                           imageURL: "/assets/images/mung-bean-pork-fat.png?v=400d407e"),
            CatalogProduct(productID: id(13), slug: "mung-bean-vegetarian", name: "Bánh đậu xanh chay",
                           description: "Đậu xanh nghiền mịn, không nhân mỡ.", priceVND: 45_000,
                           imageURL: "/assets/images/mung-bean-vegetarian.png?v=f49a203d"),
            CatalogProduct(productID: id(14), slug: "mung-bean-egg-yolk-pork-fat", name: "Bánh đậu xanh trứng mỡ",
                           description: "Đậu xanh, trứng muối và mỡ.", priceVND: 55_000,
                           imageURL: "/assets/images/mung-bean-egg-yolk-pork-fat.png?v=6f699e7f"),
        ],
        districts: [
            CatalogDistrict(districtID: id(21), name: "Quận 1", deliveryFeeVND: 15_000),
            CatalogDistrict(districtID: id(22), name: "Quận 3", deliveryFeeVND: 15_000),
            CatalogDistrict(districtID: id(23), name: "Quận 5", deliveryFeeVND: 20_000),
            CatalogDistrict(districtID: id(24), name: "Phú Nhuận", deliveryFeeVND: 20_000),
            CatalogDistrict(districtID: id(25), name: "Bình Thạnh", deliveryFeeVND: 25_000),
        ],
        slots: [
            CatalogSlot(slotID: id(31), start: "08:00", end: "10:00"),
            CatalogSlot(slotID: id(32), start: "10:00", end: "12:00"),
            CatalogSlot(slotID: id(33), start: "14:00", end: "16:00"),
            CatalogSlot(slotID: id(34), start: "16:00", end: "18:00"),
        ]
    )
}
#endif
