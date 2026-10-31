import Foundation

/// Everything `POST /v1/orders` reads and writes. A protocol so the service is
/// tested with fakes; `PostgresOrderRepository` holds the SQL of ADR-0008.
protocol OrderRepository: Sendable {
    /// Settings and the rows the request names. Unknown ids are simply absent
    /// from the result; inactive rows are present and flagged.
    /// - Throws: `CatalogRepositoryError.shopNotFound` for an unknown shop.
    func loadReferenceData(shopID: UUID, productIDs: [UUID], slotID: UUID, districtID: UUID) async throws -> OrderReferenceData

    /// The order stored under this key, if any (FR-16).
    func findOrder(shopID: UUID, idempotencyKey: UUID) async throws -> StoredOrder?

    /// Orders created for this E.164 phone at or after `since` (ADR-0014).
    func countOrders(shopID: UUID, phone: String, since: Date) async throws -> Int

    /// One transaction: take capacity, insert the order, its items and the
    /// `created` event. Nothing is written for any outcome but `.created`.
    func insertOrder(_ order: NewOrder) async throws -> OrderInsertOutcome
}

struct StoredOrder: Equatable, Sendable {
    let placed: PlacedOrder
    let requestHash: String
}

enum OrderInsertOutcome: Equatable, Sendable {
    case created(PlacedOrder)
    /// The guarded `day_load` update changed no row (BR-1, AC-22).
    case capacityExceeded
    /// Another request stored an order under the same key first.
    case duplicateKey
    /// The generated code already exists (ADR-0009); draw again.
    case codeCollision
}
