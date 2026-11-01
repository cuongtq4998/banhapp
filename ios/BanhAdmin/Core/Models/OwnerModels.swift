import Foundation

/// Owner contract types (api/07 10.13 to 10.18). Keys are snake_case on the wire.
nonisolated struct ShopInfo: Codable, Equatable, Sendable {
    var name: String
    var greeting: String
    var phoneContact: String
    var zaloContact: String
}

nonisolated struct OrderingRules: Codable, Equatable, Sendable {
    var dailyLimit: Int
    var leadDays: Int
    var minQty: Int
    var maxDaysAhead: Int
}

/// A date that already holds more cakes than the (new) daily limit.
nonisolated struct OverLimitDate: Codable, Equatable, Sendable {
    let date: String
    let cakesAccepted: Int
}

/// `GET .../ordering/impact` 200.
nonisolated struct OrderingImpact: Codable, Equatable, Sendable {
    let dailyLimit: Int
    let overLimit: [OverLimitDate]
    let count: Int
}

/// `PUT .../settings/ordering` 200: the section plus the list true at save time.
nonisolated struct OrderingSaved: Codable, Equatable, Sendable {
    let dailyLimit: Int
    let leadDays: Int
    let minQty: Int
    let maxDaysAhead: Int
    let overLimit: [OverLimitDate]
    let count: Int
}

nonisolated struct Cake: Codable, Equatable, Hashable, Sendable, Identifiable {
    let cakeId: String
    var name: String
    var description: String
    var priceVnd: Int
    var isActive: Bool
    let imageUrl: String

    var id: String { cakeId }
}

nonisolated struct OwnerDistrict: Codable, Equatable, Sendable, Identifiable {
    let districtId: String
    var name: String
    var deliveryFeeVnd: Int
    var isActive: Bool

    var id: String { districtId }
}

nonisolated struct OwnerSlot: Codable, Equatable, Sendable, Identifiable {
    let slotId: String
    var start: String
    var end: String
    var isActive: Bool

    var id: String { slotId }
}

/// `GET /v1/owner/settings` 200.
nonisolated struct OwnerSettings: Codable, Equatable, Sendable {
    var shop: ShopInfo
    var ordering: OrderingRules
    var cakes: [Cake]
    var districts: [OwnerDistrict]
    var slots: [OwnerSlot]
    let cakeCountMax: Int
    let staffCountMax: Int

    var activeCakes: Int { cakes.filter(\.isActive).count }
}

nonisolated struct StaffAccount: Codable, Equatable, Sendable, Identifiable {
    let accountId: String
    let name: String
    let email: String
    let role: AccountRole
    let isActive: Bool

    var id: String { accountId }
}

nonisolated struct StaffList: Codable, Equatable, Sendable {
    let accounts: [StaffAccount]
}
