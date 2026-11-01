/// A calendar day of the shop (Vietnam time) written `YYYY-MM-DD` on the wire. The server date of a
/// response is compared with delivery dates through this type, never through the device clock.
public struct ShopDay: Equatable, Comparable, Hashable, Sendable {
    /// Days since 1970-01-01 (proleptic Gregorian), so two days subtract without a calendar.
    public let epochDay: Int
    public let year: Int
    public let month: Int
    public let day: Int

    public init?(_ text: String) {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day)
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    private init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
        // Howard Hinnant's days_from_civil.
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400
        let dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        epochDay = era * 146_097 + dayOfEra - 719_468
    }

    public static func < (lhs: ShopDay, rhs: ShopDay) -> Bool { lhs.epochDay < rhs.epochDay }

    /// Whole days from `other` to `self` (positive when `self` is later).
    public func days(since other: ShopDay) -> Int { epochDay - other.epochDay }

    /// The next day, written `YYYY-MM-DD`.
    public func adding(days count: Int) -> ShopDay {
        ShopDay(epochDay: epochDay + count)
    }

    private init(epochDay: Int) {
        // Howard Hinnant's civil_from_days.
        let z = epochDay + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let dayOfEra = z - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let mp = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * mp + 2) / 5 + 1
        let month = mp < 10 ? mp + 3 : mp - 9
        self.init(year: yearOfEra + era * 400 + (month <= 2 ? 1 : 0), month: month, day: day)
    }

    /// `YYYY-MM-DD`.
    public var wire: String {
        func pad(_ value: Int, _ width: Int) -> String {
            String(repeating: "0", count: max(0, width - String(value).count)) + String(value)
        }
        return "\(pad(year, 4))-\(pad(month, 2))-\(pad(day, 2))"
    }

    /// `dd/MM`.
    public var shortText: String {
        (day < 10 ? "0" : "") + "\(day)/" + (month < 10 ? "0" : "") + "\(month)"
    }

    /// `dd/MM/yyyy`.
    public var longText: String { shortText + "/\(year)" }
}
