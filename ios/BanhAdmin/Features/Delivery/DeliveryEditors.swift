import BanhContracts
import BanhCore
import Foundation
import Observation

/// Sheet model of a district: name and fee (1 to 10,000,000 dong, no free delivery).
@Observable
final class DistrictEditorModel: Identifiable {
    let existing: OwnerDistrict?
    var name: String
    var fee: String
    private(set) var errors: [String: String] = [:]
    var banner: String?
    var focusRequest: String?
    private(set) var isBusy = false
    private let api: any OwnerAPI
    private let onSaved: () -> Void

    init(existing: OwnerDistrict?, api: any OwnerAPI, onSaved: @escaping () -> Void) {
        self.existing = existing
        self.api = api
        self.onSaved = onSaved
        name = existing?.name ?? ""
        fee = existing.map { FieldRules.grouped(String($0.deliveryFeeVnd)) } ?? ""
    }

    var canSave: Bool {
        guard !isBusy else { return false }
        guard let existing else { return true }
        return FieldRules.trimmed(name) != existing.name || FieldRules.number(fee) != existing.deliveryFeeVnd
    }

    @discardableResult
    func validate() -> Bool {
        var found: [String: String] = [:]
        if let text = FieldRules.text(name, AStrings.fDistrict, max: 100) { found["name"] = text }
        if let text = FieldRules.integer(fee, AStrings.fFeeEstimate, range: 1...10_000_000) { found["delivery_fee_vnd"] = text }
        errors = found
        focusRequest = found["name"] != nil ? AdminOwnerID.districtName : (found["delivery_fee_vnd"] != nil ? AdminOwnerID.districtFee : nil)
        return found.isEmpty
    }

    func save() async {
        banner = nil
        guard validate(), let value = FieldRules.number(fee) else { return }
        isBusy = true
        defer { isBusy = false }
        let trimmed = FieldRules.trimmed(name)
        do {
            if let existing {
                var changes: [String: JSONValue] = [:]
                if trimmed != existing.name { changes["name"] = .string(trimmed) }
                if value != existing.deliveryFeeVnd { changes["delivery_fee_vnd"] = .int(value) }
                _ = try await api.updateDistrict(id: existing.districtId, changes: changes)
            } else {
                _ = try await api.addDistrict(name: trimmed, feeVnd: value)
            }
            onSaved()
        } catch {
            fail(error)
        }
    }

    private func fail(_ error: Error) {
        guard !(error is SessionEnded) else { return }
        guard let failure = error as? APIError, failure.code == "VALIDATION_FAILED", !failure.fieldProblems.isEmpty else {
            return banner = error.saveMessage
        }
        var found: [String: String] = [:]
        for problem in failure.fieldProblems {
            switch (problem.field, problem.code) {
            case ("name", "NAME_TAKEN"): found["name"] = String(localized: AStrings.errDistrictDup)
            case ("name", _): found["name"] = FieldRules.server(problem, AStrings.fDistrict, max: 100)
            case ("delivery_fee_vnd", _): found["delivery_fee_vnd"] = FieldRules.server(problem, AStrings.fFeeEstimate, range: 1...10_000_000)
            default: banner = String(localized: AStrings.errGeneric)
            }
        }
        errors = found
    }
}

/// Sheet model of a time slot: start and end as minutes since midnight (24 hour clock).
@Observable
final class SlotEditorModel: Identifiable {
    let existing: OwnerSlot?
    var start: Int
    var end: Int
    var error: String?
    private(set) var isBusy = false
    private let api: any OwnerAPI
    private let onSaved: () -> Void

    init(existing: OwnerSlot?, api: any OwnerAPI, onSaved: @escaping () -> Void) {
        self.existing = existing
        self.api = api
        self.onSaved = onSaved
        start = existing.flatMap { Self.minutes($0.start) } ?? 8 * 60
        end = existing.flatMap { Self.minutes($0.end) } ?? 10 * 60
    }

    static func minutes(_ text: String) -> Int? {
        let parts = text.split(separator: ":").compactMap { Int($0) }
        return parts.count == 2 ? parts[0] * 60 + parts[1] : nil
    }

    static func text(_ minutes: Int) -> String { String(format: "%02d:%02d", minutes / 60, minutes % 60) }

    var canSave: Bool {
        guard !isBusy else { return false }
        guard let existing else { return true }
        return Self.text(start) != existing.start || Self.text(end) != existing.end
    }

    func save() async {
        error = nil
        guard start < end else { return error = String(localized: AStrings.errSlotOrder) }
        isBusy = true
        defer { isBusy = false }
        do {
            if let existing {
                _ = try await api.updateSlot(id: existing.slotId, changes: ["start": .string(Self.text(start)), "end": .string(Self.text(end))])
            } else {
                _ = try await api.addSlot(start: Self.text(start), end: Self.text(end))
            }
            onSaved()
        } catch {
            guard !(error is SessionEnded) else { return }
            switch (error as? APIError)?.code {
            case "SLOT_DUPLICATE": self.error = String(localized: AStrings.errSlotDup)
            case "VALIDATION_FAILED": self.error = String(localized: AStrings.errSlotOrder)
            default: self.error = error.saveMessage
            }
        }
    }
}
