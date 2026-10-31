import Foundation

extension BusinessDate {
    /// True when the day exists in the Gregorian calendar (`2026-02-30` does
    /// not). `init?(isoString:)` only checks the shape.
    var isRealCalendarDay: Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return false }
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return parts.year == year && parts.month == month && parts.day == day
    }
}
