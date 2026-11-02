import Foundation

/// Texts with placeholders. The catalogue holds `%@` for each `{name}`; the arguments are formatted
/// strings, so the result never depends on the device locale.
extension AStrings {
    static func fill(_ resource: LocalizedStringResource, _ args: [String]) -> String {
        String(format: String(localized: resource), arguments: args)
    }

    static func codePrompt(email: String) -> String { fill(LocalizedStringResource("A_CODE_PROMPT"), [email]) }
    static func resendWait(seconds: Int) -> String { fill(LocalizedStringResource("A_RESEND_WAIT"), [String(seconds)]) }
    static func rateSend(minutes: Int) -> String { fill(LocalizedStringResource("A_ERR_RATE_SEND"), [String(minutes)]) }
    static func overdue(days: Int) -> String { fill(LocalizedStringResource("A_OVERDUE"), [String(days)]) }
    static func tabBadgeA11y(count: Int) -> String { fill(LocalizedStringResource("A_TAB_BADGE_A11Y"), [String(count)]) }
    static func rowDelivery(date: String, slot: String) -> String { fill(LocalizedStringResource("A_ROW_DELIVERY"), [date, slot]) }
    static func rowMeta(cakes: Int, total: String, district: String) -> String {
        fill(LocalizedStringResource("A_ROW_META"), [String(cakes), total, district])
    }
    static func call(phone: String) -> String { fill(LocalizedStringResource("A_CALL"), [phone]) }
    static func placedAt(_ datetime: String) -> String { fill(LocalizedStringResource("A_PLACED_AT"), [datetime]) }
    static func lastChanged(name: String, datetime: String) -> String {
        fill(LocalizedStringResource("A_LAST_CHANGED"), [name, datetime])
    }
    static func conflict(status: String) -> String { fill(LocalizedStringResource("A_CONFLICT"), [status]) }
    static func completeTitle(code: String) -> String { fill(LocalizedStringResource("A_COMPLETE_TITLE"), [code]) }
    static func cancelBody(code: String) -> String { fill(LocalizedStringResource("A_CANCEL_BODY"), [code]) }
    static func cancelConfirm(code: String) -> String { fill(LocalizedStringResource("A_CANCEL_CONFIRM"), [code]) }

    static func status(_ status: OrderStatus) -> LocalizedStringResource {
        switch status {
        case .new: statusNew
        case .confirmed: statusConfirmed
        case .completed: statusCompleted
        case .cancelled: statusCancelled
        }
    }

    static func reason(_ reason: CancelReason) -> LocalizedStringResource {
        switch reason {
        case .customerAsked: reasonCustomer
        case .cannotDeliver: reasonCannotDeliver
        case .cannotReachCustomer: reasonNoContact
        case .fakeSpam: reasonSpam
        }
    }
}
