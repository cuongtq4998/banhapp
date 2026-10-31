import BanhContracts
import Foundation

/// The order in progress (ADR-0011): kept on the device after every change, restored after the
/// system ends the app, and thrown away after 24 hours without a change. Personal data on the
/// customer's own device; it leaves the device only inside the order itself.
nonisolated struct OrderDraft: Codable, Equatable, Sendable {
    /// Bump when the stored shape changes; a draft of another version is discarded.
    static let currentVersion = 1
    static let lifetime: TimeInterval = 24 * 60 * 60

    struct Item: Codable, Equatable, Sendable {
        let productID: ResourceID
        /// Name at the time the cake was added, so the "cake removed" message can name a cake the
        /// catalog no longer lists (UI document 5.5).
        var name: String
        var quantity: Int
    }

    var version = OrderDraft.currentVersion
    /// Cakes in the order of the catalog, only those added at least once; quantity 0 means "removed".
    var items: [Item] = []
    var date: ShopDate?
    var slotID: ResourceID?
    var name = ""
    var phone = ""
    var address = ""
    var districtID: ResourceID?
    var note = ""
    /// The total the customer last saw, sent as `expected_total_vnd`; nil until the review sets it
    /// (and after `PRICE_CHANGED` replaces it, slice 3).
    var expectedTotalVND: Int?
    /// One key per request body (ADR-0008 v1.1): `OrderFlow` replaces it on every change of a body
    /// field and keeps it for a pure retry (offline, timeout, 5xx, 429, app restart).
    var idempotencyKey = UUID()
    var savedAt: Date

    init(savedAt: Date) {
        self.savedAt = savedAt
    }

    /// The fields of the `POST /v1/orders` body that decide whether a retry is the same request.
    /// Cakes at quantity 0 are not sent, so they are not part of it; names are display only.
    struct RequestBody: Equatable {
        let quantities: [ResourceID: Int]
        let date: ShopDate?
        let slotID: ResourceID?
        let name: String
        let phone: String
        let address: String
        let districtID: ResourceID?
        let note: String
        var expectedTotalVND: Int?
    }

    /// The same fields without the acknowledged total: what the customer chose, apart from the price
    /// they saw. A change here makes a price override from `PRICE_CHANGED` stale.
    var choices: RequestBody {
        var copy = requestBody
        copy.expectedTotalVND = nil
        return copy
    }

    var requestBody: RequestBody {
        RequestBody(
            quantities: Dictionary(uniqueKeysWithValues: items.filter { $0.quantity > 0 }.map { ($0.productID, $0.quantity) }),
            date: date, slotID: slotID, name: name, phone: phone, address: address,
            districtID: districtID, note: note, expectedTotalVND: expectedTotalVND
        )
    }

    func isExpired(at now: Date) -> Bool {
        now.timeIntervalSince(savedAt) >= Self.lifetime
    }

    func quantity(of productID: ResourceID) -> Int {
        items.first { $0.productID == productID }?.quantity ?? 0
    }

    var totalQuantity: Int { items.reduce(0) { $0 + $1.quantity } }

    mutating func setQuantity(_ quantity: Int, of productID: ResourceID, name: String) {
        if let index = items.firstIndex(where: { $0.productID == productID }) {
            items[index].quantity = quantity
            items[index].name = name
        } else {
            items.append(Item(productID: productID, name: name, quantity: quantity))
        }
    }
}
