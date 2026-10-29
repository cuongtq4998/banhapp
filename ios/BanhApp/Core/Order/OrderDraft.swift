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
    /// One key per attempt at one content (ADR-0008); replaced when the content changes under the
    /// customer (a cake dropped from the draft).
    var idempotencyKey = UUID()
    var savedAt: Date

    init(savedAt: Date) {
        self.savedAt = savedAt
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
