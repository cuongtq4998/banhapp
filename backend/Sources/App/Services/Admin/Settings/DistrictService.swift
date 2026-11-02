import Foundation
import BanhContracts

/// Delivery districts (api/07 10.16). Earlier orders keep their snapshot of
/// name and fee, so a change here touches new orders only.
struct DistrictService: Sendable {
    let store: SettingsStore
    let clock: any WallClock
    let shopID: UUID

    func create(_ body: [String: JSONValue], principal: AdminPrincipal) async throws -> DistrictView {
        var form = FormReader(body, allowed: ["name", "delivery_fee_vnd"])
        let name = form.text("name", 1...100), fee = form.integer("delivery_fee_vnd", 1...10_000_000)
        try form.finish()
        guard let name, let fee else { throw APIError(.validationFailed) }
        let batch = ChangeBatch(shopID: shopID, accountID: principal.accountID, actorName: principal.displayName, at: clock.now())
        let created = DistrictView(districtID: UUID(), name: name, deliveryFeeVND: fee, isActive: true)
        return try await store.write { [shopID] writer in
            try await writer.lock(shopID: shopID)
            if try await writer.districtNameTaken(shopID: shopID, name: name, excluding: nil) {
                throw FormReader.refusal("name", "NAME_TAKEN", "TAKEN")
            }
            try await writer.insertDistrict(shopID: shopID, created, at: batch.at)
            try await writer.record(batch, entity: "district", id: created.districtID, Self.changes(from: nil, to: created))
            return created
        }
    }

    func update(id: UUID, _ body: [String: JSONValue], principal: AdminPrincipal) async throws -> DistrictView {
        var form = FormReader(body, allowed: ["name", "delivery_fee_vnd", "is_active"])
        form.requireAny()
        let name = form.text("name", 1...100, required: false), fee = form.integer("delivery_fee_vnd", 1...10_000_000, required: false)
        let active = form.bool("is_active", required: false)
        try form.finish()
        let batch = ChangeBatch(shopID: shopID, accountID: principal.accountID, actorName: principal.displayName, at: clock.now())
        return try await store.write { [shopID] writer in
            try await writer.lock(shopID: shopID)
            guard let old = try await writer.district(shopID: shopID, id: id) else { throw APIError(.notFound) }
            let new = DistrictView(districtID: id, name: name ?? old.name, deliveryFeeVND: fee ?? old.deliveryFeeVND, isActive: active ?? old.isActive)
            if new.name != old.name, try await writer.districtNameTaken(shopID: shopID, name: new.name, excluding: id) {
                throw FormReader.refusal("name", "NAME_TAKEN", "TAKEN")
            }
            if old.isActive, !new.isActive, try await writer.otherActiveDistricts(shopID: shopID, besides: id) == 0 {
                throw APIError(.lastActiveDistrict)
            }
            try await writer.updateDistrict(new, at: batch.at)
            try await writer.record(batch, entity: "district", id: id, Self.changes(from: old, to: new))
            return new
        }
    }

    private static func changes(from old: DistrictView?, to new: DistrictView) -> [FieldChange] {
        [FieldChange(field: "name", old: old?.name, new: new.name),
         FieldChange(field: "delivery_fee_vnd", old: old.map { String($0.deliveryFeeVND) }, new: String(new.deliveryFeeVND)),
         FieldChange(field: "is_active", old: old.map { String($0.isActive) }, new: String(new.isActive))]
    }
}
