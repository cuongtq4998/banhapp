import Foundation
import BanhContracts

/// Delivery slots (api/07 10.16). A slot is a pair of clock times; the pair is
/// unique. Earlier orders keep their snapshot of the times.
struct SlotService: Sendable {
    let store: SettingsStore
    let clock: any WallClock
    let shopID: UUID

    func create(_ body: [String: JSONValue], principal: AdminPrincipal) async throws -> SlotView {
        var form = FormReader(body, allowed: ["start", "end"])
        let start = Self.time("start", &form, required: true), end = Self.time("end", &form, required: true)
        Self.checkOrder(start, end, &form)
        try form.finish()
        guard let start, let end else { throw APIError(.validationFailed) }
        let batch = ChangeBatch(shopID: shopID, accountID: principal.accountID, actorName: principal.displayName, at: clock.now())
        let created = SlotView(slotID: UUID(), start: start, end: end, isActive: true)
        return try await store.write { [shopID] writer in
            try await writer.lock(shopID: shopID)
            if try await writer.slotPairTaken(shopID: shopID, start: start, end: end, excluding: nil) { throw APIError(.slotDuplicate) }
            try await writer.insertSlot(shopID: shopID, created, at: batch.at)
            try await writer.renumberSlots(shopID: shopID, at: batch.at)
            try await writer.record(batch, entity: "slot", id: created.slotID, Self.changes(from: nil, to: created))
            return created
        }
    }

    func update(id: UUID, _ body: [String: JSONValue], principal: AdminPrincipal) async throws -> SlotView {
        var form = FormReader(body, allowed: ["start", "end", "is_active"])
        form.requireAny()
        let start = Self.time("start", &form, required: false), end = Self.time("end", &form, required: false)
        let active = form.bool("is_active", required: false)
        try form.finish()
        let batch = ChangeBatch(shopID: shopID, accountID: principal.accountID, actorName: principal.displayName, at: clock.now())
        return try await store.write { [shopID] writer in
            try await writer.lock(shopID: shopID)
            guard let old = try await writer.slot(shopID: shopID, id: id) else { throw APIError(.notFound) }
            let new = SlotView(slotID: id, start: start ?? old.start, end: end ?? old.end, isActive: active ?? old.isActive)
            var order = FormReader([:], allowed: [])
            Self.checkOrder(new.start, new.end, &order)
            try order.finish()
            if (new.start, new.end) != (old.start, old.end),
               try await writer.slotPairTaken(shopID: shopID, start: new.start, end: new.end, excluding: id) {
                throw APIError(.slotDuplicate)
            }
            if old.isActive, !new.isActive, try await writer.otherActiveSlots(shopID: shopID, besides: id) == 0 {
                throw APIError(.lastActiveSlot)
            }
            try await writer.updateSlot(new, at: batch.at)
            try await writer.renumberSlots(shopID: shopID, at: batch.at)
            try await writer.record(batch, entity: "slot", id: id, Self.changes(from: old, to: new))
            return new
        }
    }

    /// `HH:MM`, 00:00 to 23:59.
    private static func time(_ key: String, _ form: inout FormReader, required: Bool) -> String? {
        guard let text = form.text(key, 5...5, required: required) else { return nil }
        guard text.range(of: #"^([01][0-9]|2[0-3]):[0-5][0-9]$"#, options: .regularExpression) != nil else {
            form.fail(key, "INVALID")
            return nil
        }
        return text
    }

    /// Both texts are `HH:MM`, so the text order is the clock order.
    private static func checkOrder(_ start: String?, _ end: String?, _ form: inout FormReader) {
        if let start, let end, start >= end { form.fail("end", "OUT_OF_RANGE") }
    }

    private static func changes(from old: SlotView?, to new: SlotView) -> [FieldChange] {
        [FieldChange(field: "start", old: old?.start, new: new.start),
         FieldChange(field: "end", old: old?.end, new: new.end),
         FieldChange(field: "is_active", old: old.map { String($0.isActive) }, new: String(new.isActive))]
    }
}
