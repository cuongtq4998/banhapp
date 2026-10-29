import BanhContracts
import Foundation
import Observation

/// S-7: name, phone, address, district and the optional note (FR-8, FR-13, FR-18). Validation runs
/// when the customer taps Next; an error clears as soon as its field becomes valid (UI document 5.7).
@MainActor
@Observable
final class RecipientViewModel {
    enum Field: CaseIterable {
        case name, phone, address, district, note
    }

    enum Problem: Equatable {
        case nameRequired, phoneRequired, phoneInvalid, addressRequired, districtRequired, noteTooLong
    }

    struct DistrictRow: Identifiable, Equatable {
        let id: ResourceID
        let name: String
        let feeText: String
    }

    private(set) var problems: [Field: Problem] = [:]
    /// The field the view should focus after a failed Next.
    private(set) var focusRequest: Field?

    private let flow: OrderFlow

    init(flow: OrderFlow) {
        self.flow = flow
    }

    // MARK: Values

    var name: String { flow.draft.name }
    var phone: String { flow.draft.phone }
    var address: String { flow.draft.address }
    var note: String { flow.draft.note }

    var noteMaxLength: Int { flow.settings?.noteMaxLength ?? OrderValidation.noteMaxLength }
    var noteLength: Int { min(OrderValidation.length(note), noteMaxLength) }

    func setName(_ value: String) {
        flow.setName(OrderValidation.limited(value, to: OrderValidation.nameMaxLength).text)
        revalidate(.name)
    }

    func setPhone(_ value: String) {
        flow.setPhone(value)
        revalidate(.phone)
    }

    func setAddress(_ value: String) {
        flow.setAddress(OrderValidation.limited(value, to: OrderValidation.addressMaxLength).text)
        revalidate(.address)
    }

    /// The 201st character is not inserted and pasted text is cut (AC-26); the message stays until the
    /// customer edits the note without hitting the limit again.
    func setNote(_ value: String) {
        let (text, wasCut) = OrderValidation.limited(value, to: noteMaxLength)
        flow.setNote(text)
        problems[.note] = wasCut ? .noteTooLong : nil
    }

    // MARK: Districts

    var districts: Load<[DistrictRow]> {
        flow.catalog.map { catalog in
            catalog.districts.map {
                DistrictRow(id: $0.districtID, name: $0.name, feeText: MoneyFormatter.format($0.deliveryFeeVND))
            }
        }
    }

    /// The chosen district when the catalog still serves it; an unserved one counts as not chosen (AC-11).
    var selectedDistrict: DistrictRow? {
        guard case .ready(let rows) = districts else { return nil }
        return rows.first { $0.id == flow.draft.districtID }
    }

    func select(_ district: DistrictRow) {
        flow.setDistrict(district.id)
        revalidate(.district)
    }

    func retryDistricts() async { await flow.refreshCatalog() }

    /// Next is disabled only when the shop serves no district at all.
    var canContinue: Bool {
        if case .ready(let rows) = districts, rows.isEmpty { false } else { true }
    }

    // MARK: Validation

    /// Checks every required field at once, shows each error, asks for focus on the first failing
    /// field and tells whether the flow may advance (AC-12).
    func validateAll() -> Bool {
        problems = Dictionary(uniqueKeysWithValues: Field.allCases.compactMap { field in problem(for: field).map { (field, $0) } })
        focusRequest = Field.allCases.first { problems[$0] != nil }
        return problems.isEmpty
    }

    func focusHandled() { focusRequest = nil }

    private func revalidate(_ field: Field) {
        guard problems[field] != nil else { return }
        problems[field] = problem(for: field)
    }

    private func problem(for field: Field) -> Problem? {
        switch field {
        case .name:
            return OrderValidation.isValidName(name) ? nil : .nameRequired
        case .phone:
            if OrderValidation.canonical(phone).isEmpty { return .phoneRequired }
            return OrderValidation.validPhone(phone) == nil ? .phoneInvalid : nil
        case .address:
            return OrderValidation.isValidAddress(address) ? nil : .addressRequired
        case .district:
            return selectedDistrict == nil ? .districtRequired : nil
        case .note:
            return OrderValidation.isValidNote(note, max: noteMaxLength) ? nil : .noteTooLong
        }
    }
}
