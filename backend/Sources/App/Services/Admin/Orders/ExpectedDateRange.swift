import Foundation
import BanhContracts

/// The dates the shop accepts as an expected delivery date: shop today to
/// today + 7. Built once per request from one clock read.
struct ExpectedDateRange: Sendable, Equatable {
    static let maxDaysAhead = 7

    let min: BusinessDate
    let max: BusinessDate

    init(today: BusinessDate, calendar: ShopCalendar) {
        min = today
        max = calendar.adding(days: Self.maxDaysAhead, to: today)
    }

    /// The same object api/09 puts in the detail and in range errors.
    var json: JSONValue { .object(["min": .string(min.description), "max": .string(max.description)]) }

    var view: DateRangeView { DateRangeView(min: min.description, max: max.description) }

    /// The error for a date outside the range; nil when inside.
    func violation(of date: BusinessDate) -> APIError? {
        let code: String
        if date < min { code = "EXPECTED_DATE_PAST" } else if date > max { code = "EXPECTED_DATE_TOO_FAR" } else { return nil }
        return APIError(
            .validationFailed,
            fields: [.init(field: StatusRequest.dateKey, code: code, messageKey: APIErrorCode.genericMessageKey)],
            details: ["expected_date_range": json]
        )
    }
}
