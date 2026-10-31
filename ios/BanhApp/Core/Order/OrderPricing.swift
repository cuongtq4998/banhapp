import BanhContracts

/// Money of an order (BR-5): the sum of price times quantity for each cake, plus the flat fee of the
/// chosen district. Whole dong, so there is nothing to round.
nonisolated struct OrderPricing: Equatable {
    struct Line: Equatable {
        let productID: ResourceID
        let name: String
        let quantity: Int
        let unitPriceVND: Int

        var lineTotalVND: Int { unitPriceVND * quantity }
    }

    /// Only cakes with a quantity above 0, in catalog order (AC-6).
    let lines: [Line]
    let deliveryFeeVND: Int

    var cakeCount: Int { lines.reduce(0) { $0 + $1.quantity } }
    var subtotalVND: Int { lines.reduce(0) { $0 + $1.lineTotalVND } }
    var totalVND: Int { subtotalVND + deliveryFeeVND }

    private init(lines: [Line], deliveryFeeVND: Int) {
        self.lines = lines
        self.deliveryFeeVND = deliveryFeeVND
    }

    /// The server's prices of a `PRICE_CHANGED` answer in place of the catalog's (ADR-0010). A cake the
    /// answer does not list keeps its price.
    func applying(_ details: PriceChangedDetails) -> OrderPricing {
        let current = Dictionary(details.items.map { ($0.productID, $0.priceVND) }, uniquingKeysWith: { _, last in last })
        return OrderPricing(
            lines: lines.map { Line(productID: $0.productID, name: $0.name, quantity: $0.quantity,
                                    unitPriceVND: current[$0.productID] ?? $0.unitPriceVND) },
            deliveryFeeVND: details.deliveryFeeVND
        )
    }

    /// Prices are the catalog's current ones; a cake that is no longer in the catalog has no price
    /// and is left out (the flow drops it from the draft, BR-13).
    init(draft: OrderDraft, catalog: CatalogResponse) {
        lines = catalog.products.compactMap { product in
            let quantity = draft.quantity(of: product.productID)
            guard quantity > 0 else { return nil }
            return Line(productID: product.productID, name: product.name, quantity: quantity, unitPriceVND: product.priceVND)
        }
        deliveryFeeVND = catalog.districts.first { $0.districtID == draft.districtID }?.deliveryFeeVND ?? 0
    }
}
