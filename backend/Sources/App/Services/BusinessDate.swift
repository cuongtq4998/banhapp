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

extension BusinessDate {
    /// Parses the wire form `YYYY-MM-DD`; nil for anything else, including
    /// a malformed shape or month, so a corrupt database value is not
    /// silently accepted.
    init?(isoString: String) {
        let parts = isoString.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day) else { return nil }
        self.init(year: year, month: month, day: day)
    }
}
