import BanhContracts
import Foundation
import Observation

/// S-6: the receiving date from the server's availability for this order size, and one time slot
/// (FR-6, FR-7). The date rules (BR-1, BR-2, BR-8) are the server's; the app only shows its answer.
@MainActor
@Observable
final class DateViewModel {
    struct Slot: Identifiable, Equatable {
        let id: ResourceID
        let label: String
    }

    private(set) var availability: Load<DayAvailability> = .loading
    /// Month shown, as an offset from the month of today.
    private(set) var monthOffset = 0
    /// Set when the chosen date stopped fitting the order after the customer changed the quantities.
    private(set) var dateWasCleared = false

    private let flow: OrderFlow
    private let api: any AvailabilityAPI

    init(flow: OrderFlow, api: any AvailabilityAPI) {
        self.flow = flow
        self.api = api
    }

    // MARK: Data

    func load() async {
        availability = .loading
        guard case .ready(let catalog) = flow.catalog, !catalog.slots.isEmpty else {
            availability = .failed(.other)
            return
        }
        do {
            let response = try await api.fetchAvailability(cakes: flow.draft.totalQuantity)
            guard let days = DayAvailability(response: response) else { throw APIError.invalidResponse }
            apply(days, catalog: catalog)
            availability = .ready(days)
        } catch {
            availability = .failed((error as? APIError) == .networkUnavailable ? .network : .other)
        }
    }

    /// Re-checks the choices against the fresh answer: a date without room is cleared, the slot stays
    /// (UI document 5.6 Validation); a slot the shop removed is cleared too.
    private func apply(_ days: DayAvailability, catalog: CatalogResponse) {
        if let date = flow.draft.date, !days.state(of: date).isSelectable {
            flow.setDate(nil)
            dateWasCleared = true
        }
        if let slot = flow.draft.slotID, !catalog.slots.contains(where: { $0.slotID == slot }) {
            flow.setSlot(nil)
        }
        let shown = flow.draft.date ?? days.firstSelectableDate ?? days.serverDate
        monthOffset = max(0, min(shown.monthsSince(days.serverDate), lastMonthOffset(days)))
    }

    // MARK: Calendar

    var serverDate: ShopDate? {
        if case .ready(let days) = availability { days.serverDate } else { nil }
    }

    /// The first day of the month on show.
    var shownMonth: ShopDate? { serverDate.map { $0.adding(months: monthOffset) } }

    var canShowPreviousMonth: Bool { monthOffset > 0 }

    var canShowNextMonth: Bool {
        guard case .ready(let days) = availability else { return false }
        return monthOffset < lastMonthOffset(days)
    }

    func showPreviousMonth() { if canShowPreviousMonth { monthOffset -= 1 } }
    func showNextMonth() { if canShowNextMonth { monthOffset += 1 } }

    private func lastMonthOffset(_ days: DayAvailability) -> Int { days.lastDate.monthsSince(days.serverDate) }

    func state(of date: ShopDate) -> DayState {
        guard case .ready(let days) = availability else { return .tooSoon }
        let state = days.state(of: date)
        return state == .available && date == flow.draft.date ? .selected : state
    }

    /// "Nhận bánh từ {from} đến {to}." (the range the server accepts).
    var rangeHint: String? {
        guard case .ready(let days) = availability, let settings = flow.settings else { return nil }
        return OrderStrings.format(
            OrderStrings.dateRangeHint,
            days.serverDate.adding(days: settings.leadDays).displayText, days.serverDate.adding(days: settings.maxDaysAhead).displayText
        )
    }

    var leadDays: Int { flow.settings?.leadDays ?? 0 }
    var maxDaysAhead: Int { flow.settings?.maxDaysAhead ?? 0 }

    /// Every date is unavailable for this order size (Empty state).
    var hasNoSelectableDate: Bool {
        if case .ready(let days) = availability { !days.hasSelectableDate } else { false }
    }

    func select(_ date: ShopDate) {
        guard state(of: date).isSelectable else { return }
        dateWasCleared = false
        flow.setDate(date)
    }

    // MARK: Slots

    var slots: [Slot] {
        guard case .ready(let catalog) = flow.catalog else { return [] }
        return catalog.slots.map { Slot(id: $0.slotID, label: OrderStrings.format(OrderStrings.slotLabel, $0.start, $0.end)) }
    }

    var selectedSlot: ResourceID? { flow.draft.slotID }
    func select(_ slot: Slot) { flow.setSlot(slot.id) }

    /// Next needs a date and a slot (FR-6, FR-7).
    var canContinue: Bool {
        guard case .ready = availability else { return false }
        return flow.draft.date != nil && flow.draft.slotID != nil
    }
}
