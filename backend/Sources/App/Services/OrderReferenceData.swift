import Foundation

/// What the service needs to know about the shop to judge one order.
struct OrderReferenceData: Equatable, Sendable {
    let rules: AvailabilityRules
    /// BR-4.
    let minQty: Int
    /// Rows named by the request that exist, active or not.
    let products: [UUID: OrderProductRecord]
    let slot: OrderSlotRecord?
    let district: OrderDistrictRecord?
}

struct OrderProductRecord: Equatable, Sendable {
    let id: UUID
    let name: String
    let priceVND: Int
    let isActive: Bool
}

struct OrderSlotRecord: Equatable, Sendable {
    let id: UUID
    /// `HH:MM:SS`, snapshotted on the order.
    let startTime: String
    let endTime: String
    let isActive: Bool
}

struct OrderDistrictRecord: Equatable, Sendable {
    let id: UUID
    let name: String
    let deliveryFeeVND: Int
    let isActive: Bool
}

/// A line with the price at confirmation (BR-6, AC-23).
struct PricedLine: Equatable, Sendable {
    let productID: UUID
    let productName: String
    let unitPriceVND: Int
    let quantity: Int
    var lineTotalVND: Int { unitPriceVND * quantity }
}

/// Everything `insertOrder` stores. All values are decided by the service.
struct NewOrder: Equatable, Sendable {
    let shopID: UUID
    let orderID: UUID
    let orderCode: String
    let idempotencyKey: UUID
    let requestHash: String
    let request: OrderRequest
    let lines: [PricedLine]
    let slot: OrderSlotRecord
    let district: OrderDistrictRecord
    let itemsSubtotalVND: Int
    let totalVND: Int
    /// The current `shop_setting.daily_limit`, used by the guarded update.
    let dailyLimit: Int
    let platform: String
    let appVersion: String
    let createdAt: Date
}
