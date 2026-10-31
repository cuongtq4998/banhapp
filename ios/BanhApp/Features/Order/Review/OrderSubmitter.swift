import BanhContracts
import Foundation
import Observation

/// Sends the order and keeps the state S-8 shows around it (FR-11, FR-16, FR-17). One instance per
/// order flow, so leaving S-8 while a send is under way neither lets a second send start nor loses its
/// result. The Idempotency-Key rules (ADR-0008 v1.1) are applied here: a pure retry keeps the key, and
/// `OrderFlow` replaces it whenever a field of the body changes.
@MainActor
@Observable
final class OrderSubmitter {
    private(set) var isSending = false
    private(set) var highlight = PriceHighlight()
    /// Grows with every notice, so the screen can scroll the banner into view.
    private(set) var noticeCount = 0
    private var notice: SendNotice?
    /// What the order looked like when a rule error came back; the error holds until it changes.
    private var noticeChoices: OrderDraft.RequestBody?

    private let flow: OrderFlow
    private let api: any OrderAPI
    private let onPlaced: (PlacedOrder) -> Void

    init(flow: OrderFlow, api: any OrderAPI, onPlaced: @escaping (PlacedOrder) -> Void) {
        self.flow = flow
        self.api = api
        self.onPlaced = onPlaced
    }

    /// The banner to show now. A rule error disappears once the customer changed the order (a new
    /// date, quantity or district); the other kinds stay until the next attempt.
    var activeNotice: SendNotice? {
        guard let notice else { return nil }
        return notice.kind == .rule && flow.draft.choices != noticeChoices ? nil : notice
    }

    var isBlocked: Bool { activeNotice?.kind == .rule }

    /// Taps on an Edit control or on a banner action: the price banner and its highlight have done their job.
    func acknowledgePriceChange() {
        if notice == .priceChanged { notice = nil }
        highlight = PriceHighlight()
    }

    func send() async {
        guard !isSending, !isBlocked, let total = flow.pricing?.totalVND else { return }
        isSending = true
        notice = nil
        flow.acknowledgeTotal(total)
        var keyReplaced = false
        while true {
            guard let body = flow.draft.orderRequest() else { return fail(.server) }
            do {
                let placed = try await api.placeOrder(body, idempotencyKey: flow.draft.idempotencyKey)
                flow.discardDraft()
                highlight = PriceHighlight()
                // `isSending` stays true: the screen is replaced, and nothing may send again.
                onPlaced(placed)
                return
            } catch OrderFailure.keyReused where !keyReplaced {
                // The server saw this key with another body: a new key, one more try (ADR-0008 v1.1).
                keyReplaced = true
                flow.replaceIdempotencyKey()
            } catch let failure as OrderFailure {
                await handle(failure)
                return
            } catch {
                return fail(.server)
            }
        }
    }

    private func handle(_ failure: OrderFailure) async {
        switch failure {
        case .offline: fail(.offline)
        case .timeout: fail(.timeout)
        case .server, .keyReused: fail(.server)
        case .rateLimited(let seconds): fail(.rateLimited(retryAfterSeconds: seconds))
        case .priceChanged(let details): applyPriceChange(details)
        case .validation(let fields): rejectFields(fields)
        case .minQty(let min):
            let required = min ?? flow.settings?.minQty ?? 0
            block(.minQty(required))
        case .dateLead(let days): block(.dateLead(days: days ?? flow.settings?.leadDays ?? 0))
        case .dateHorizon(let max): block(.dateHorizon(maxDays: max ?? flow.settings?.maxDaysAhead ?? 0))
        case .dateCapacity(let iso):
            let date = iso.flatMap { ShopDate(iso: $0) } ?? flow.draft.date
            block(.dateCapacity(deliveryDate: date?.displayText ?? ""))
        case .districtUnserved:
            await flow.refreshCatalog()
            block(.districtUnserved)
        case .slotUnavailable:
            await flow.refreshCatalog()
            block(.slotUnavailable)
        case .productUnavailable(let ids):
            await flow.refreshCatalog()
            flow.dropProducts(ids)
            block(.productUnavailable)
        }
    }

    private func applyPriceChange(_ details: PriceChangedDetails) {
        let before = flow.pricing
        flow.applyPriceChange(details)
        highlight = Self.changes(from: before, to: flow.pricing)
        fail(.priceChanged)
    }

    /// `VALIDATION_FAILED`: S-7 shows what it can; anything else is a plain "not sent".
    private func rejectFields(_ fields: [APIErrorResponse.FieldError]) {
        guard fields.contains(where: { RecipientViewModel.problem(forServerField: $0) != nil }) else {
            return fail(.server)
        }
        flow.rejectFields(fields)
        isSending = false
        fieldsRejected = true
    }

    /// Set when the server rejected fields S-7 can show; the screen takes it once and goes to S-7.
    private(set) var fieldsRejected = false

    func fieldRejectionHandled() { fieldsRejected = false }

    private func block(_ rule: SendNotice) {
        noticeChoices = flow.draft.choices
        fail(rule)
    }

    private func fail(_ notice: SendNotice) {
        self.notice = notice
        noticeCount += 1
        isSending = false
    }

    private static func changes(from before: OrderPricing?, to after: OrderPricing?) -> PriceHighlight {
        guard let before, let after else { return PriceHighlight() }
        let was = Dictionary(before.lines.map { ($0.productID, $0.unitPriceVND) }, uniquingKeysWith: { _, last in last })
        return PriceHighlight(
            productIDs: Set(after.lines.filter { was[$0.productID] != $0.unitPriceVND }.map(\.productID)),
            fee: before.deliveryFeeVND != after.deliveryFeeVND,
            total: before.totalVND != after.totalVND
        )
    }
}
