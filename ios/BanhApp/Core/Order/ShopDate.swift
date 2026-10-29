import Foundation

/// A calendar date in shop time, with no time of day and no time zone. Dates come from the server as
/// `YYYY-MM-DD` and are only ever shifted and formatted here, so the device clock and time zone never
/// matter (BR-2, AC-7).
nonisolated struct ShopDate: Hashable, Comparable, Codable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private static let daysPerWeek = 7

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Parses `YYYY-MM-DD`; nil for anything else, including dates that do not exist.
    init?(iso: String) {
        let parts = iso.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else { return nil }
        let candidate = ShopDate(year: year, month: month, day: day)
        guard candidate.foundationDate.map({ ShopDate(foundation: $0) }) == candidate else { return nil }
        self = candidate
    }

    private init(foundation date: Date) {
        let parts = Self.calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    private var foundationDate: Date? {
        Self.calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    var iso: String { String(format: "%04d-%02d-%02d", year, month, day) }

    /// `dd/MM/yyyy` (FR-21, AC-31).
    var displayText: String { String(format: "%02d/%02d/%04d", day, month, year) }

    func adding(days: Int) -> ShopDate {
        ShopDate(foundation: Self.calendar.date(byAdding: .day, value: days, to: foundationDate!)!)
    }

    var firstOfMonth: ShopDate { ShopDate(year: year, month: month, day: 1) }

    func adding(months: Int) -> ShopDate {
        ShopDate(foundation: Self.calendar.date(byAdding: .month, value: months, to: firstOfMonth.foundationDate!)!)
    }

    var daysInMonth: Int { Self.calendar.range(of: .day, in: .month, for: foundationDate!)!.count }

    /// 0 for Monday to 6 for Sunday: Vietnamese calendars start the week on Monday.
    var weekdayIndex: Int {
        let sundayFirst = Self.calendar.component(.weekday, from: foundationDate!)
        return (sundayFirst + Self.daysPerWeek - 2) % Self.daysPerWeek
    }

    /// Number of months from `other`'s month to this date's month.
    func monthsSince(_ other: ShopDate) -> Int { (year - other.year) * 12 + month - other.month }

    static func < (lhs: ShopDate, rhs: ShopDate) -> Bool { lhs.iso < rhs.iso }

    init(from decoder: any Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let date = ShopDate(iso: text) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not a date"))
        }
        self = date
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(iso)
    }
}
