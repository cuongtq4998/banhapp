import BanhContracts
import Foundation
import Observation

/// S-8: the whole order before confirmation (FR-9) and the rules that block it (FR-10). Sending the
/// order is the next slice: `canConfirm` is false until a confirm action is wired in.
@MainActor
@Observable
final class ReviewViewModel {
    /// A rule the order does not meet, with the step that fixes it (UI document 5.8, Error kind a).
    struct Blocker: Equatable {
        let message: String
        let actionTitle: LocalizedStringResource
        let step: OrderStep
    }

    struct Summary: Equatable {
        let lines: [OrderPricing.Line]
        let feeText: String
        let totalText: String
        let dateText: String
        let timeText: String
        let name: String
        let phone: String
        let address: String
        /// Nil when no note was entered; the row is then not shown.
        let note: String?
    }

    private let flow: OrderFlow
    /// Slice 3 supplies the action that sends the order; until then the button stays disabled.
    let confirmAction: (() -> Void)?

    init(flow: OrderFlow, confirmAction: (() -> Void)? = nil) {
        self.flow = flow
        self.confirmAction = confirmAction
    }

    /// Loading and failed come from the catalog, which holds the prices and fees.
    var summary: Load<Summary> {
        flow.catalog.map { catalog in
            let draft = flow.draft
            let pricing = OrderPricing(draft: draft, catalog: catalog)
            let district = catalog.districts.first { $0.districtID == draft.districtID }
            let slot = catalog.slots.first { $0.slotID == draft.slotID }
            let note = OrderValidation.canonical(draft.note)
            return Summary(
                lines: pricing.lines,
                feeText: MoneyFormatter.format(pricing.deliveryFeeVND),
                totalText: MoneyFormatter.format(pricing.totalVND),
                dateText: draft.date?.displayText ?? "",
                timeText: slot.map { OrderStrings.format(OrderStrings.slotLabel, $0.start, $0.end) } ?? "",
                name: OrderValidation.canonical(draft.name),
                phone: OrderValidation.canonical(draft.phone),
                address: [OrderValidation.canonical(draft.address), district?.name].compactMap { $0 }.joined(separator: ", "),
                note: note.isEmpty ? nil : note
            )
        }
    }

    /// The first rule the order breaks, checked against the catalog the app holds; nil when none.
    /// The server checks again on confirmation (capacity, lead time, horizon, prices; slice 3).
    var blocker: Blocker? {
        guard case .ready(let catalog) = flow.catalog else { return nil }
        let draft = flow.draft
        let offered = Set(catalog.products.map(\.productID))
        if draft.items.contains(where: { $0.quantity > 0 && !offered.contains($0.productID) }) {
            return Blocker(message: String(localized: OrderStrings.errorProductUnavailable),
                           actionTitle: OrderStrings.dateEmptyAction, step: .cakes)
        }
        let cakes = OrderPricing(draft: draft, catalog: catalog).cakeCount
        if cakes < catalog.settings.minQty {
            return Blocker(message: OrderStrings.format(OrderStrings.errorMinQty, catalog.settings.minQty),
                           actionTitle: OrderStrings.dateEmptyAction, step: .cakes)
        }
        if draft.date == nil {
            return Blocker(message: String(localized: OrderStrings.nextHintDateTime),
                           actionTitle: OrderStrings.actionChooseDate, step: .date)
        }
        if !catalog.slots.contains(where: { $0.slotID == draft.slotID }) {
            return Blocker(message: String(localized: OrderStrings.errorSlotUnavailable),
                           actionTitle: OrderStrings.actionChooseSlot, step: .date)
        }
        if !catalog.districts.contains(where: { $0.districtID == draft.districtID }) {
            return Blocker(message: String(localized: OrderStrings.errorDistrictUnserved),
                           actionTitle: OrderStrings.actionChooseDistrict, step: .recipient)
        }
        return nil
    }

    func refresh() async { await flow.refreshCatalog() }

    /// True while the order is on its way (the sending slice sets it); the privacy link is disabled then.
    var isSending = false

    var canConfirm: Bool { confirmAction != nil && blocker == nil }

    func confirm() {
        if canConfirm { confirmAction?() }
    }
}
