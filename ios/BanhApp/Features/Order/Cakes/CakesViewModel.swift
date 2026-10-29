import BanhContracts
import Foundation
import Observation

/// S-5: a quantity for each active cake (FR-5, BR-13).
@MainActor
@Observable
final class CakesViewModel {
    struct Row: Identifiable, Equatable {
        let id: ResourceID
        let name: String
        let priceText: String
        let imageURL: URL?
        let quantity: Int
        let canDecrease: Bool
        let canIncrease: Bool
    }

    private let flow: OrderFlow
    private let assetBaseURL: URL

    init(flow: OrderFlow, assetBaseURL: URL) {
        self.flow = flow
        self.assetBaseURL = assetBaseURL
    }

    /// Loading and failed come from the catalog; a catalog without cakes is `.ready([])` (the Empty state).
    var rows: Load<[Row]> {
        flow.catalog.map { catalog in
            catalog.products.map { product in
                let quantity = flow.draft.quantity(of: product.productID)
                return Row(
                    id: product.productID, name: product.name,
                    priceText: MoneyFormatter.format(product.priceVND),
                    imageURL: assetBaseURL.resolvingAsset(product.imageURL),
                    quantity: quantity, canDecrease: quantity > 0,
                    canIncrease: quantity < catalog.settings.maxQtyPerCake
                )
            }
        }
    }

    var minQty: Int { flow.settings?.minQty ?? 0 }
    var totalCakes: Int { flow.draft.totalQuantity }
    /// Cakes of the draft that are in the catalog; the total of the draft may hold a cake that is gone only briefly.
    var subtotalText: String { MoneyFormatter.format(flow.pricing?.subtotalVND ?? 0) }
    var showsMinHint: Bool { totalCakes < minQty }
    var removedCakeNames: [String] { flow.removedCakeNames }

    /// Next is enabled only when the cakes reach the minimum (BR-4, AC-13).
    var canContinue: Bool {
        guard case .ready(let rows) = rows, !rows.isEmpty else { return false }
        return totalCakes >= minQty
    }

    func increase(_ row: Row) {
        guard row.canIncrease, let product = product(row.id) else { return }
        flow.setQuantity(row.quantity + 1, of: product)
    }

    func decrease(_ row: Row) {
        guard row.canDecrease, let product = product(row.id) else { return }
        flow.setQuantity(row.quantity - 1, of: product)
    }

    /// Entry to S-5 refreshes prices and cakes (ADR-0011); also serves as retry.
    func load() async {
        await flow.refreshCatalog()
    }

    func leave() {
        flow.dismissRemovedNotice()
    }

    private func product(_ id: ResourceID) -> CatalogProduct? {
        guard case .ready(let catalog) = flow.catalog else { return nil }
        return catalog.products.first { $0.productID == id }
    }
}
