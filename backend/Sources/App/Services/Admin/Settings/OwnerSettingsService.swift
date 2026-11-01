import Foundation
import BanhContracts

/// Shop information and ordering rules of the owner (api/07 10.13 to 10.15).
/// Every save is one transaction: lock, compare, update, record (BR-3, BR-11).
struct OwnerSettingsService: Sendable {
    static let cakeCountMax = 12
    static let staffCountMax = 30

    let store: SettingsStore
    let calendar: ShopCalendar
    let assets: AssetURLBuilder
    let shopID: UUID

    func overview() async throws -> SettingsResponse {
        try await store.read { [shopID, assets] queries in
            guard let shop = try await queries.shop(id: shopID), let ordering = try await queries.ordering(shopID: shopID) else {
                throw CatalogRepositoryError.shopNotFound
            }
            return SettingsResponse(
                shop: shop, ordering: ordering, cakes: try await queries.cakes(shopID: shopID, assets: assets),
                districts: try await queries.districts(shopID: shopID), slots: try await queries.slots(shopID: shopID),
                cakeCountMax: Self.cakeCountMax, staffCountMax: Self.staffCountMax
            )
        }
    }

    func ordering() async throws -> OrderingSection {
        try await store.read { [shopID] queries in
            guard let section = try await queries.ordering(shopID: shopID) else { throw CatalogRepositoryError.shopNotFound }
            return section
        }
    }

    func saveShop(_ body: [String: JSONValue], principal: AdminPrincipal) async throws -> ShopSection {
        var form = FormReader(body, allowed: ["name", "greeting", "phone_contact", "zalo_contact"])
        let name = form.text("name", 1...100), greeting = form.text("greeting", 1...300)
        var phone = form.text("phone_contact", 8...16)
        if let value = phone, value.range(of: #"^\+[1-9][0-9]{7,14}$"#, options: .regularExpression) == nil {
            form.fail("phone_contact", "INVALID")
            phone = nil
        }
        let zalo = form.text("zalo_contact", 3...100)
        try form.finish()
        guard let name, let greeting, let phone, let zalo else { throw APIError(.validationFailed) }
        let new = ShopSection(name: name, greeting: greeting, phoneContact: phone, zaloContact: zalo)
        let batch = batch(principal)
        return try await store.write { [shopID] writer in
            try await writer.lock(shopID: shopID)
            guard let old = try await writer.queries.shop(id: shopID) else { throw CatalogRepositoryError.shopNotFound }
            try await writer.updateShop(shopID: shopID, new, at: batch.at)
            try await writer.record(batch, entity: "shop", id: nil, [
                FieldChange(field: "name", old: old.name, new: new.name),
                FieldChange(field: "greeting", old: old.greeting, new: new.greeting),
                FieldChange(field: "phone_contact", old: old.phoneContact, new: new.phoneContact),
                FieldChange(field: "zalo_contact", old: old.zaloContact, new: new.zaloContact)
            ])
            return new
        }
    }

    /// The save always succeeds inside the ranges; a limit below accepted cakes
    /// cancels nothing and the answer lists the dates that are over (BR-11).
    func saveOrdering(_ body: [String: JSONValue], principal: AdminPrincipal) async throws -> OrderingSaved {
        var form = FormReader(body, allowed: ["daily_limit", "lead_days", "min_qty"])
        let limit = form.integer("daily_limit", 1...9_999), lead = form.integer("lead_days", 0...14)
        var minQty = form.integer("min_qty", 1...20)
        if let limit, let value = minQty, value > limit {
            form.fail("min_qty", "OUT_OF_RANGE")
            minQty = nil
        }
        try form.finish()
        guard let limit, let lead, let minQty else { throw APIError(.validationFailed) }
        let batch = batch(principal), today = calendar.businessDate(of: batch.at).description
        return try await store.write { [shopID] writer in
            try await writer.lock(shopID: shopID)
            guard let old = try await writer.queries.ordering(shopID: shopID) else { throw CatalogRepositoryError.shopNotFound }
            try await writer.updateOrdering(shopID: shopID, dailyLimit: limit, leadDays: lead, minQty: minQty, at: batch.at)
            try await writer.record(batch, entity: "ordering", id: nil, [
                FieldChange(field: "daily_limit", old: String(old.dailyLimit), new: String(limit)),
                FieldChange(field: "lead_days", old: String(old.leadDays), new: String(lead)),
                FieldChange(field: "min_qty", old: String(old.minQty), new: String(minQty))
            ])
            let over = try await writer.queries.overLimit(shopID: shopID, today: today, limit: limit)
            return OrderingSaved(dailyLimit: limit, leadDays: lead, minQty: minQty, maxDaysAhead: old.maxDaysAhead,
                                 overLimit: over, count: over.count)
        }
    }

    /// The preview: advisory, writes nothing, needs no token of its own.
    func impact(query: [String: String]) async throws -> OrderingImpact {
        var form = FormReader(query.mapValues { Int($0).map(JSONValue.int) ?? .string($0) }, allowed: ["daily_limit"])
        let limit = form.integer("daily_limit", 1...9_999)
        try form.finish()
        guard let limit else { throw APIError(.validationFailed) }
        let today = calendar.today().description
        let over = try await store.read { [shopID] queries in
            try await queries.overLimit(shopID: shopID, today: today, limit: limit)
        }
        return OrderingImpact(dailyLimit: limit, overLimit: over, count: over.count)
    }

    private func batch(_ principal: AdminPrincipal) -> ChangeBatch {
        ChangeBatch(shopID: shopID, accountID: principal.accountID, actorName: principal.displayName, at: calendar.clock.now())
    }
}
