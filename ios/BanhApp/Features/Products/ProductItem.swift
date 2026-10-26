import BanhContracts
import Foundation

/// A cake as the screens show it: text and links already prepared, so views only lay them out.
struct ProductItem: Identifiable, Equatable {
    let id: ResourceID
    let name: String
    let description: String
    /// Price with the dong sign, for example "35.000 ₫".
    let priceText: String
    /// Nil when the catalog value cannot form a URL.
    let imageURL: URL?
}

extension CatalogProduct {
    func makeProductItem(assetBaseURL: URL) -> ProductItem {
        ProductItem(
            id: productID,
            name: name,
            description: description,
            priceText: MoneyFormatter.format(priceVND),
            imageURL: assetBaseURL.resolvingAsset(imageURL)
        )
    }
}

extension ResourceID {
    /// Stable text for accessibility identifiers.
    var identifierText: String { description }
}
