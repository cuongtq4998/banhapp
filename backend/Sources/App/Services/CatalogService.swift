import Foundation
import Logging
import BanhContracts

/// Assembles the body of `GET /v1/catalog` (api.md 4.1).
struct CatalogService: Sendable {
    let repository: any CatalogRepository
    let calendar: ShopCalendar
    let assets: AssetURLBuilder
    let logger: Logger

    func makeCatalog(shopID: UUID) async throws -> CatalogResponse {
        let snapshot = try await repository.loadCatalog(shopID: shopID)
        warnAboutMissingImages(in: snapshot.products)
        return CatalogResponse(
            // Today in shop time, so clients never rely on the device date.
            serverDate: calendar.today().description,
            shop: snapshot.shop,
            settings: CatalogSettings(
                minQty: snapshot.ordering.minQty,
                leadDays: snapshot.ordering.leadDays,
                maxDaysAhead: snapshot.ordering.maxDaysAhead,
                maxQtyPerCake: snapshot.ordering.maxQtyPerCake,
                noteMaxLength: InputLimits.noteMaxLength
            ),
            products: snapshot.products.map { $0.toContract(assets: assets) },
            districts: snapshot.districts,
            slots: snapshot.slots
        )
    }
}

extension CatalogService {
    /// A product without an image file still lists (the app shows a
    /// placeholder), but the operator must hear about it. Only the path is
    /// logged; it is shop data, not customer data.
    fileprivate func warnAboutMissingImages(in products: [ProductRecord]) {
        for product in products where !assets.hasVersion(forPath: product.imagePath) {
            logger.warning("Product image file not found", metadata: ["image_path": .string(product.imagePath)])
        }
    }
}

extension ProductRecord {
    func toContract(assets: AssetURLBuilder) -> CatalogProduct {
        CatalogProduct(
            productID: ResourceID(id),
            slug: slug,
            name: name,
            description: description,
            priceVND: priceVND,
            imageURL: assets.imageURL(forPath: imagePath)
        )
    }
}
