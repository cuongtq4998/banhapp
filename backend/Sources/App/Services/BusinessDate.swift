import Foundation

/// A calendar date in shop time (`YYYY-MM-DD` on the wire, api.md section 1).
/// A value type of its own so a date can never be mixed up with an instant.
struct BusinessDate: Hashable, Comparable, Sendable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    static func < (lhs: BusinessDate, rhs: BusinessDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}
