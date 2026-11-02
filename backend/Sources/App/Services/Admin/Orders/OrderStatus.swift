import Foundation

/// The six order steps (order-process.md section 1).
enum OrderStatus: String, Codable, Sendable, CaseIterable {
    case received = "Received"
    case processing = "Processing"
    case deliveryDateScheduled = "DeliveryDateScheduled"
    case deliveryStarted = "DeliveryStarted"
    case finished = "Finished"
    case cancelled = "Cancelled"

    /// The four steps still being worked, in process order.
    static let open: [OrderStatus] = [.received, .processing, .deliveryDateScheduled, .deliveryStarted]
    /// The two final steps.
    static let final: [OrderStatus] = [.finished, .cancelled]

    var isOpen: Bool { Self.open.contains(self) }

    /// The next step on the happy path; nil for the final steps.
    private var nextStep: OrderStatus? {
        switch self {
        case .received: return .processing
        case .processing: return .deliveryDateScheduled
        case .deliveryDateScheduled: return .deliveryStarted
        case .deliveryStarted: return .finished
        case .finished, .cancelled: return nil
        }
    }

    /// Steps from which the order may still be cancelled.
    private var canCancel: Bool { self == .received || self == .processing }

    /// Whether the pair is allowed; the database trigger holds the same pairs.
    func canMove(to target: OrderStatus) -> Bool {
        if target == .cancelled { return canCancel }
        return nextStep == target
    }

    /// Actions the apps may offer, by status (all for owner and staff).
    var allowedActions: [OrderAction] {
        switch self {
        case .received: return [.process, .cancel]
        case .processing: return [.scheduleDelivery, .cancel]
        case .deliveryDateScheduled: return [.startDelivery, .changeDate]
        case .deliveryStarted: return [.finish, .correctFee]
        case .finished, .cancelled: return []
        }
    }
}

/// Buttons of the order detail; every role that may change an order may use them.
enum OrderAction: String, Codable, Sendable, CaseIterable {
    case process
    case scheduleDelivery = "schedule_delivery"
    case startDelivery = "start_delivery"
    case finish
    case cancel
    case changeDate = "change_date"
    case correctFee = "correct_fee"
}

/// BR-8: exactly four reasons.
enum CancelReason: String, Codable, Sendable, CaseIterable {
    case customerAsked = "customer_asked"
    case cannotDeliver = "cannot_deliver"
    case cannotReachCustomer = "cannot_reach_customer"
    case fakeSpam = "fake_spam"
}
