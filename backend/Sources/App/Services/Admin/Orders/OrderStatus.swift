import Foundation

/// The four order states (order-lifecycle.md section 6).
enum OrderStatus: String, Codable, Sendable, CaseIterable {
    case new = "New"
    case confirmed = "Confirmed"
    case completed = "Completed"
    case cancelled = "Cancelled"

    var isOpen: Bool { self == .new || self == .confirmed }

    /// BR-2: the only four moves. The database trigger enforces the same table.
    func canMove(to target: OrderStatus) -> Bool {
        switch (self, target) {
        case (.new, .confirmed), (.new, .cancelled), (.confirmed, .completed), (.confirmed, .cancelled): return true
        default: return false
        }
    }

    /// Buttons the app may show (api/06 10.10); empty for final states.
    var allowedActions: [String] {
        switch self {
        case .new: return ["confirm", "cancel"]
        case .confirmed: return ["complete", "cancel"]
        case .completed, .cancelled: return []
        }
    }
}

/// BR-8: exactly four reasons.
enum CancelReason: String, Codable, Sendable, CaseIterable {
    case customerAsked = "customer_asked"
    case cannotDeliver = "cannot_deliver"
    case cannotReachCustomer = "cannot_reach_customer"
    case fakeSpam = "fake_spam"
}
