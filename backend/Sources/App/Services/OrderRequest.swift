import Foundation

/// A validated, normalised `POST /v1/orders` body (api.md 4.3). Text is NFC
/// and trimmed, the phone is E.164, and the note is nil when empty, so two
/// writings of the same order are equal and hash alike (ADR-0008).
struct OrderRequest: Equatable, Sendable {
    struct Line: Equatable, Sendable {
        let productID: UUID
        let quantity: Int
    }

    let items: [Line]
    let deliveryDate: BusinessDate
    let slotID: UUID
    let customerName: String
    /// E.164, `+84` and nine digits (ADR-0009).
    let customerPhone: String
    let customerAddress: String
    let districtID: UUID
    let note: String?
    /// Acknowledgement only; the server computes the total (ADR-0010).
    let expectedTotalVND: Int

    var totalCakes: Int { items.reduce(0) { $0 + $1.quantity } }
}

/// Header values of a request that passed `OrderHeaders` (api.md 4.3).
struct OrderCommand: Sendable {
    let shopID: UUID
    let request: OrderRequest
    let idempotencyKey: UUID
    let platform: String
    let appVersion: String
}

/// What the customer is told about an accepted order (FR-11).
struct PlacedOrder: Equatable, Sendable {
    let orderCode: String
    /// ISO 8601 UTC with `Z`, whole seconds, formatted by the database.
    let createdAt: String
}

enum OrderPlacementResult: Equatable, Sendable {
    case created(PlacedOrder)
    /// The same key and body again: the stored result, nothing written (AC-19).
    case replayed(PlacedOrder)
}
