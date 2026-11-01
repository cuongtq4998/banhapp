import Foundation

/// Texts of the settings, cakes and staff copy that carry placeholders.
extension AStrings {
    private static func field(_ name: LocalizedStringResource) -> String { String(localized: name) }

    static func errRequired(_ name: LocalizedStringResource) -> String {
        fill(LocalizedStringResource("A_ERR_REQUIRED"), [field(name)])
    }

    static func errTooLong(_ name: LocalizedStringResource, max: Int) -> String {
        fill(LocalizedStringResource("A_ERR_TOO_LONG"), [field(name), String(max)])
    }

    static func errRangeInt(_ name: LocalizedStringResource, min: Int, max: Int) -> String {
        fill(LocalizedStringResource("A_ERR_RANGE_INT"), [field(name), String(min), String(max)])
    }

    static func errPhone(_ name: LocalizedStringResource) -> String {
        fill(LocalizedStringResource("A_ERR_PHONE"), [field(name)])
    }

    static func errMinAboveLimit(_ name: LocalizedStringResource) -> String {
        fill(LocalizedStringResource("A_ERR_MIN_ABOVE_LIMIT"), [field(name)])
    }

    static func rowRulesValue(limit: Int) -> String { fill(LocalizedStringResource("A_ROW_RULES_VALUE"), [String(limit)]) }

    static func rowDeliveryValue(districts: Int, slots: Int) -> String {
        fill(LocalizedStringResource("A_ROW_DELIVERY_VALUE"), [String(districts), String(slots)])
    }

    static func limitWarnBody(count: Int) -> String { fill(LocalizedStringResource("A_LIMIT_WARN_BODY"), [String(count)]) }
    static func cakesCount(_ count: Int) -> String { fill(LocalizedStringResource("A_CAKES_COUNT"), [String(count)]) }
    static func staffCount(_ count: Int) -> String { fill(LocalizedStringResource("A_STAFF_COUNT"), [String(count)]) }
    static func removeTitle(name: String) -> String { fill(LocalizedStringResource("A_REMOVE_TITLE"), [name]) }
    static func deactivateTitle(name: String) -> String { fill(LocalizedStringResource("A_DEACTIVATE_TITLE"), [name]) }
    static func deactivateBody(name: String) -> String { fill(LocalizedStringResource("A_DEACTIVATE_BODY"), [name]) }
    static func notifForeground(code: String) -> String { fill(LocalizedStringResource("A_NOTIF_FOREGROUND"), [code]) }

    /// "Đang tải ảnh…": the transport reports no byte progress, so the percent of the copy is left out.
    static var uploading: String {
        fill(LocalizedStringResource("A_UPLOADING"), [""]).replacingOccurrences(of: " %", with: "")
    }

    /// `{n}/{max}` style counters of a text field (`120/300`).
    static func counter(_ count: Int, max: Int) -> String { "\(count)/\(max)" }
}
