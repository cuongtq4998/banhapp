import BanhCore
import Foundation

/// Dates and times as the shop reads them (Vietnam time, UTC+7 without daylight saving).
nonisolated enum AdminFormatting {
    private static let vietnam = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? TimeZone(secondsFromGMT: 7 * 3600)!

    /// `31/10 10:15` for an instant like `2026-10-31T03:15:09Z`; the raw text when it cannot be read.
    static func dateTime(_ iso: String) -> String {
        guard let date = parse(iso) else { return iso }
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")
        format.timeZone = vietnam
        format.dateFormat = "dd/MM/yyyy HH:mm"
        return format.string(from: date)
    }

    private static func parse(_ iso: String) -> Date? {
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: iso) { return date }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: iso)
    }

    /// `Thứ hai, 02/11/2026`: the weekday from the system's Vietnamese calendar names.
    static func weekdayAndDate(_ wire: String) -> String {
        guard let day = ShopDay(wire) else { return wire }
        let noon = Date(timeIntervalSince1970: TimeInterval(day.epochDay * 86_400 + 43_200))
        let format = DateFormatter()
        format.locale = Locale(identifier: "vi_VN")
        format.timeZone = TimeZone(secondsFromGMT: 0)
        format.dateFormat = "EEEE"
        return "\(format.string(from: noon).capitalized), \(day.longText)"
    }

    /// `dd/MM` of a delivery date, for the list rows.
    static func shortDate(_ wire: String) -> String { ShopDay(wire)?.shortText ?? wire }

    /// The shop calendar: Gregorian in Vietnam time, whatever the zone of the device.
    static var shopCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = vietnam
        return calendar
    }

    static var shopTimeZone: TimeZone { vietnam }

    /// The shop date (Vietnam calendar day) of a `DatePicker` value, for the one-date filter.
    static func wire(of date: Date) -> String {
        let parts = shopCalendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }

    /// Noon of a shop date, to start a `DatePicker` on the server's "today" (now when unreadable).
    static func pickerDate(_ wire: String) -> Date {
        guard let day = ShopDay(wire) else { return Date() }
        return Date(timeIntervalSince1970: TimeInterval(day.epochDay * 86_400 + 43_200 - 7 * 3_600))
    }
}
