#if DEBUG
import Foundation

/// The order process rules of the fake server (docs/system/api/09 10.13): transitions, the date
/// window and the fee rules, as pure functions over one order.
nonisolated enum StubOrderProcess {
    struct Outcome {
        let reply: (Int, Data)
        var order: OrderDetail?
    }

    static let maxFee = 10_000_000
    private static let staff = "Nhan Vien A"
    private static let now = "2026-11-02T04:00:00Z"
    private static let next: [OrderStatus: [OrderStatus]] = [
        .received: [.processing, .cancelled], .processing: [.deliveryDateScheduled, .cancelled],
        .deliveryDateScheduled: [.deliveryStarted], .deliveryStarted: [.finished],
    ]

    private static func refuse(_ code: String, details: [String: Any] = [:]) -> Outcome {
        Outcome(reply: StubReply.error(422, code, "ERR_\(code)", details: details))
    }

    private static func range(_ order: OrderDetail) -> [String: Any] {
        let range = StubOrderData.range(for: order.status)
        return ["expected_date_range": ["min": range?.min ?? "", "max": range?.max ?? ""]]
    }

    static func changeStatus(_ order: OrderDetail, target: OrderStatus, _ json: [String: Any]) -> Outcome {
        guard next[order.status]?.contains(target) == true else { return refuse("STATUS_TRANSITION_INVALID") }
        let reason = (json["cancel_reason"] as? String).flatMap(CancelReason.init(rawValue:))
        switch target {
        case .cancelled where reason == nil: return refuse("CANCEL_REASON_REQUIRED")
        case .deliveryDateScheduled:
            guard let date = json["expected_delivery_date"] as? String else { return refuse("VALIDATION_FAILED") }
            if let problem = dateProblem(order, date) { return problem }
            return done(StubOrderData.rebuilt(order, status: target, expected: date))
        case .deliveryStarted:
            guard let fee = json["delivery_fee_vnd"] as? Int else { return refuse("FEE_REQUIRED") }
            guard (0...maxFee).contains(fee) else { return refuse("FEE_INVALID") }
            return done(StubOrderData.rebuilt(order, status: target, finalFee: fee))
        default: return done(StubOrderData.rebuilt(order, status: target, reason: reason?.rawValue))
        }
    }

    private static func dateProblem(_ order: OrderDetail, _ date: String) -> Outcome? {
        guard let window = StubOrderData.range(for: order.status) else { return refuse("VALIDATION_FAILED") }
        if date < window.min { return refuse("EXPECTED_DATE_PAST") }
        if date > window.max { return refuse("EXPECTED_DATE_TOO_FAR", details: range(order)) }
        return nil
    }

    static func changeDate(_ order: OrderDetail, _ json: [String: Any]) -> Outcome {
        guard let date = json["expected_delivery_date"] as? String else { return refuse("VALIDATION_FAILED") }
        guard order.status == .deliveryDateScheduled else { return refuse("STATUS_TRANSITION_INVALID") }
        if date == order.expectedDeliveryDate { return refuse("EXPECTED_DATE_UNCHANGED") }
        if let problem = dateProblem(order, date) { return problem }
        let change = DateChange(oldDate: order.expectedDeliveryDate ?? "", newDate: date, changedByName: staff, changedAt: now)
        return done(StubOrderData.rebuilt(order, status: order.status, expected: date, dateChange: change))
    }

    static func correctFee(_ order: OrderDetail, _ json: [String: Any]) -> Outcome {
        guard order.status == .deliveryStarted, let current = order.deliveryFeeFinalVnd else {
            return refuse("FEE_CORRECTION_NOT_ALLOWED")
        }
        guard let fee = json["delivery_fee_vnd"] as? Int, (0...maxFee).contains(fee) else { return refuse("FEE_INVALID") }
        if let previous = json["previous_delivery_fee_vnd"] as? Int, previous != current {
            return Outcome(reply: StubReply.error(409, "ORDER_STATE_CHANGED", "ERR_ORDER_STATE_CHANGED", details: ["order": StubReply.object(order)]))
        }
        if fee == current { return refuse("FEE_UNCHANGED") }
        let change = FeeCorrection(oldFeeVnd: current, newFeeVnd: fee, changedByName: staff, changedAt: now)
        return done(StubOrderData.rebuilt(order, status: order.status, finalFee: fee, feeCorrection: change))
    }

    private static func done(_ order: OrderDetail) -> Outcome {
        Outcome(reply: StubReply.codable(200, order), order: order)
    }
}
#endif
