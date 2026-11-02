import Foundation
import BanhContracts

/// The owner's cakes (api/07 10.17; FR-21, BR-12). Every write is one
/// transaction: lock the shop row, check the rules, write, record (BR-3).
/// Removal keeps earlier orders intact because they hold their own copy of
/// name, quantity and price (ADR-0031).
struct CakeService: Sendable {
    static let textFields: Set<String> = ["name", "description", "price_vnd"]

    let store: SettingsStore
    let clock: any WallClock
    let assets: AssetURLBuilder
    let shopID: UUID

    func create(_ form: MultipartFields, principal: AdminPrincipal) async throws -> CakeView {
        var reader = FormReader(Self.values(of: form), allowed: Self.textFields.union(["image"]))
        let name = reader.text("name", 1...100), description = reader.text("description", 1...300)
        let price = reader.integer("price_vnd", 1...100_000_000)
        let image = try Self.checkImage(form, &reader)
        try reader.finish()
        guard let name, let description, let price, let image else { throw APIError(.validationFailed) }
        let batch = batch(principal), id = UUID(), assets = assets
        return try await store.write { [shopID] writer in
            try await writer.lock(shopID: shopID)
            if try await writer.liveCakeCount(shopID: shopID) >= OwnerSettingsService.cakeCountMax { throw APIError(.cakeLimitReached) }
            if try await writer.cakeNameTaken(shopID: shopID, name: name, excluding: nil) {
                throw FormReader.refusal("name", "NAME_TAKEN", "TAKEN")
            }
            try await writer.insertCake(shopID: shopID, id: id, name: name, description: description, priceVND: price, image: image, at: batch.at)
            try await writer.record(batch, entity: "cake", id: id, [
                FieldChange(field: "name", old: nil, new: name), FieldChange(field: "description", old: nil, new: description),
                FieldChange(field: "price_vnd", old: nil, new: String(price)), FieldChange(field: "is_active", old: nil, new: "true")
            ])
            guard let created = try await writer.queries.cake(shopID: shopID, id: id, assets: assets) else { throw APIError(.internalError) }
            return created
        }
    }

    func update(id: UUID, _ body: [String: JSONValue], principal: AdminPrincipal) async throws -> CakeView {
        var form = FormReader(body, allowed: Self.textFields.union(["is_active"]))
        form.requireAny()
        let name = form.text("name", 1...100, required: false), description = form.text("description", 1...300, required: false)
        let price = form.integer("price_vnd", 1...100_000_000, required: false), active = form.bool("is_active", required: false)
        try form.finish()
        let batch = batch(principal), assets = assets
        return try await store.write { [shopID] writer in
            try await writer.lock(shopID: shopID)
            guard let old = try await writer.queries.cake(shopID: shopID, id: id, assets: assets) else { throw APIError(.notFound) }
            let new = CakeView(cakeID: id, name: name ?? old.name, description: description ?? old.description,
                               priceVND: price ?? old.priceVND, isActive: active ?? old.isActive, imageURL: old.imageURL)
            if new.name != old.name, try await writer.cakeNameTaken(shopID: shopID, name: new.name, excluding: id) {
                throw FormReader.refusal("name", "NAME_TAKEN", "TAKEN")
            }
            if old.isActive, !new.isActive, try await writer.otherActiveCakes(shopID: shopID, besides: id) == 0 {
                throw APIError(.lastActiveCake)
            }
            try await writer.updateCake(id: id, name: new.name, description: new.description, priceVND: new.priceVND, isActive: new.isActive, at: batch.at)
            try await writer.record(batch, entity: "cake", id: id, [
                FieldChange(field: "name", old: old.name, new: new.name), FieldChange(field: "description", old: old.description, new: new.description),
                FieldChange(field: "price_vnd", old: String(old.priceVND), new: String(new.priceVND)),
                FieldChange(field: "is_active", old: String(old.isActive), new: String(new.isActive))
            ])
            return new
        }
    }

    func remove(id: UUID, principal: AdminPrincipal) async throws {
        let batch = batch(principal), assets = assets
        try await store.write { [shopID] writer in
            try await writer.lock(shopID: shopID)
            guard let old = try await writer.queries.cake(shopID: shopID, id: id, assets: assets) else { throw APIError(.notFound) }
            if old.isActive, try await writer.otherActiveCakes(shopID: shopID, besides: id) == 0 { throw APIError(.lastActiveCake) }
            try await writer.removeCake(id: id, at: batch.at)
            try await writer.record(batch, entity: "cake", id: id, [
                FieldChange(field: "is_active", old: String(old.isActive), new: "false"), FieldChange(field: "removed", old: "false", new: "true")
            ])
        }
    }

    private func batch(_ principal: AdminPrincipal) -> ChangeBatch {
        ChangeBatch(shopID: shopID, accountID: principal.accountID, actorName: principal.displayName, at: clock.now())
    }
}
