import Foundation

/// Vietnam business dates. The shop timezone is fixed at UTC+7 because
/// Vietnam has no daylight saving time (assumption A-1); a fixed offset also
/// keeps the result independent of the host's timezone database.
struct ShopCalendar: Sendable {
    static let utcOffsetSeconds = 7 * 60 * 60

    let clock: any WallClock

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        // The offset is a valid constant, so the fallback only guards the optional.
        calendar.timeZone = TimeZone(secondsFromGMT: utcOffsetSeconds) ?? .gmt
        return calendar
    }

    func today() -> BusinessDate {
        businessDate(of: clock.now())
    }

    func businessDate(of instant: Date) -> BusinessDate {
        let parts = Self.calendar.dateComponents([.year, .month, .day], from: instant)
        // Gregorian components always carry all three fields.
        return BusinessDate(year: parts.year ?? 0, month: parts.month ?? 0, day: parts.day ?? 0)
    }

    func adding(days: Int, to date: BusinessDate) -> BusinessDate {
        let calendar = Self.calendar
        let start = calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day)) ?? clock.now()
        let moved = calendar.date(byAdding: .day, value: days, to: start) ?? start
        return businessDate(of: moved)
    }
}
