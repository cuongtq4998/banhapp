import Foundation
import BanhContracts

/// The server's price of an order (BR-5, BR-6): current product prices times
/// quantities, plus the district's flat fee. Clients never send these values.
struct OrderQuote: Equatable, Sendable {
    let lines: [PricedLine]
    let itemsSubtotalVND: Int
    let deliveryFeeVND: Int
    var totalVND: Int { itemsSubtotalVND + deliveryFeeVND }

    /// Prices every line. The caller has already checked that each product
    /// exists and is active, so a missing one is skipped, never invented.
    static func make(
        for request: OrderRequest, products: [UUID: OrderProductRecord], district: OrderDistrictRecord
    ) -> OrderQuote {
        let lines = request.items.compactMap { line -> PricedLine? in
            guard let product = products[line.productID] else { return nil }
            return PricedLine(
                productID: line.productID, productName: product.name,
                unitPriceVND: product.priceVND, quantity: line.quantity
            )
        }
        return OrderQuote(
            lines: lines,
            itemsSubtotalVND: lines.reduce(0) { $0 + $1.lineTotalVND },
            deliveryFeeVND: district.deliveryFeeVND
        )
    }

    /// 409 `PRICE_CHANGED` when the total the customer saw differs (ADR-0010).
    /// The details carry the current prices so the app can redraw the review.
    func requireTotal(equalTo expectedTotalVND: Int) throws {
        guard totalVND != expectedTotalVND else { return }
        let items = lines.map { line in
            JSONValue.object([
                "product_id": .string(line.productID.uuidString.lowercased()),
                "price_vnd": .int(line.unitPriceVND)
            ])
        }
        throw APIError(.priceChanged, details: [
            "items": .array(items),
            "delivery_fee_vnd": .int(deliveryFeeVND),
            "total_vnd": .int(totalVND)
        ])
    }
}
