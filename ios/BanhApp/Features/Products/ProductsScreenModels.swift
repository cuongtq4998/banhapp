import BanhContracts
import Foundation

/// The slices of the catalog that S-3 and S-4 show.
typealias ProductsScreenModel = CatalogScreenModel<[ProductItem]>
typealias ProductDetailScreenModel = CatalogScreenModel<ProductItem>

extension CatalogScreenModel where Value == [ProductItem] {
    /// S-3: every active cake, as many as the shop offers (ADR-0017). An empty list is the only failed load.
    static func products(repository: CatalogRepository, assetBaseURL: URL) -> ProductsScreenModel {
        CatalogScreenModel(repository: repository) { catalog in
            catalog.products.isEmpty
                ? .failed(.other)
                : .ready(catalog.products.map { $0.makeProductItem(assetBaseURL: assetBaseURL) })
        }
    }
}

extension CatalogScreenModel where Value == ProductItem {
    /// S-4: one cake. A product the catalog no longer holds is a failed load.
    static func product(id: ResourceID, repository: CatalogRepository, assetBaseURL: URL) -> ProductDetailScreenModel {
        CatalogScreenModel(repository: repository) { catalog in
            catalog.products.first { $0.productID == id }
                .map { .ready($0.makeProductItem(assetBaseURL: assetBaseURL)) } ?? .failed(.other)
        }
    }
}
