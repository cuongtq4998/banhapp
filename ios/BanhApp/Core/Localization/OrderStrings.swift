import Foundation

/// Display text of the order flow (S-5 to S-8), one constant per key of docs/design/place-order-ui.md
/// section 8, resolved through `Localizable.xcstrings` like `Strings`. Keys marked "new" are not in
/// that document yet (calendar month and weekday names).
enum OrderStrings {
    static let commonNext = LocalizedStringResource("COMMON_NEXT")
    static let commonEdit = LocalizedStringResource("COMMON_EDIT")
    static let productsEmpty = LocalizedStringResource("PRODUCTS_EMPTY")

    static let step2 = LocalizedStringResource("STEP2")
    static let step3 = LocalizedStringResource("STEP3")
    static let step4 = LocalizedStringResource("STEP4")

    // S-5
    static let qtyTotal = LocalizedStringResource("QTY_TOTAL")
    static let qtySubtotal = LocalizedStringResource("QTY_SUBTOTAL")
    static let qtyMinHint = LocalizedStringResource("QTY_MIN_HINT")
    static let qtyIncrease = LocalizedStringResource("QTY_INC_A11Y")
    static let qtyDecrease = LocalizedStringResource("QTY_DEC_A11Y")
    static let qtyValue = LocalizedStringResource("QTY_VALUE_A11Y")
    static let cakeRemoved = LocalizedStringResource("ORDER_CAKE_REMOVED")

    // S-6
    static let dateTitle = LocalizedStringResource("DATE_TITLE")
    static let dateRangeHint = LocalizedStringResource("DATE_HINT_RANGE")
    static let dateLegendFull = LocalizedStringResource("DATE_LEGEND_FULL")
    static let dateSelected = LocalizedStringResource("DATE_A11Y_SELECTED")
    static let dateFull = LocalizedStringResource("DATE_A11Y_FULL")
    static let dateTooSoon = LocalizedStringResource("DATE_A11Y_TOO_SOON")
    static let dateTooFar = LocalizedStringResource("DATE_A11Y_TOO_FAR")
    static let dateEmpty = LocalizedStringResource("DATE_EMPTY")
    static let dateEmptyAction = LocalizedStringResource("DATE_EMPTY_ACTION")
    static let dateError = LocalizedStringResource("DATE_ERR")
    static let dateCleared = LocalizedStringResource("DATE_CLEARED")
    static let timeTitle = LocalizedStringResource("TIME_TITLE")
    static let slotLabel = LocalizedStringResource("SLOT_LABEL")
    static let nextHintDateTime = LocalizedStringResource("NEXT_HINT_DATE_TIME")
    /// New: month title of the calendar, "Tháng {m} năm {y}".
    static let monthTitle = LocalizedStringResource("DATE_MONTH_TITLE")
    /// New: spoken labels of the month controls.
    static let monthPrevious = LocalizedStringResource("DATE_MONTH_PREV")
    static let monthNext = LocalizedStringResource("DATE_MONTH_NEXT")
    /// New: short weekday names, Monday first.
    static let weekdays = [
        LocalizedStringResource("WEEKDAY_1"), LocalizedStringResource("WEEKDAY_2"),
        LocalizedStringResource("WEEKDAY_3"), LocalizedStringResource("WEEKDAY_4"),
        LocalizedStringResource("WEEKDAY_5"), LocalizedStringResource("WEEKDAY_6"),
        LocalizedStringResource("WEEKDAY_7"),
    ]

    // S-7
    static let fieldName = LocalizedStringResource("FIELD_NAME")
    static let fieldPhone = LocalizedStringResource("FIELD_PHONE")
    static let fieldAddress = LocalizedStringResource("FIELD_ADDRESS")
    static let fieldDistrict = LocalizedStringResource("FIELD_DISTRICT")
    static let districtPlaceholder = LocalizedStringResource("DISTRICT_PLACEHOLDER")
    static let districtFee = LocalizedStringResource("DISTRICT_FEE")
    static let districtError = LocalizedStringResource("DISTRICT_ERR")
    static let districtEmpty = LocalizedStringResource("DISTRICT_EMPTY")
    static let fieldNote = LocalizedStringResource("FIELD_NOTE")
    static let noteCounter = LocalizedStringResource("NOTE_COUNTER")
    static let errorNameRequired = LocalizedStringResource("ERR_NAME_REQUIRED")
    static let errorPhoneRequired = LocalizedStringResource("ERR_PHONE_REQUIRED")
    static let errorPhoneInvalid = LocalizedStringResource("ERR_PHONE_INVALID")
    static let errorAddressRequired = LocalizedStringResource("ERR_ADDRESS_REQUIRED")
    static let errorDistrictRequired = LocalizedStringResource("ERR_DISTRICT_REQUIRED")
    static let errorNoteMax = LocalizedStringResource("ERR_NOTE_MAX")

    // S-8
    static let reviewCakes = LocalizedStringResource("REVIEW_SEC_CAKES")
    static let reviewItem = LocalizedStringResource("REVIEW_ITEM")
    static let reviewFee = LocalizedStringResource("REVIEW_FEE")
    static let reviewTotal = LocalizedStringResource("REVIEW_TOTAL")
    static let reviewDate = LocalizedStringResource("REVIEW_DATE")
    static let reviewTime = LocalizedStringResource("REVIEW_TIME")
    static let reviewName = LocalizedStringResource("REVIEW_NAME")
    static let reviewPhone = LocalizedStringResource("REVIEW_PHONE")
    static let reviewAddress = LocalizedStringResource("REVIEW_ADDRESS")
    static let reviewNote = LocalizedStringResource("REVIEW_NOTE")
    static let reviewPrivacy = LocalizedStringResource("REVIEW_PRIVACY")
    static let confirm = LocalizedStringResource("BTN_CONFIRM")
    static let errorMinQty = LocalizedStringResource("ERR_MIN_QTY")
    static let errorDistrictUnserved = LocalizedStringResource("ERR_DISTRICT_UNSERVED")
    static let errorProductUnavailable = LocalizedStringResource("ERR_PRODUCT_UNAVAILABLE")
    static let errorSlotUnavailable = LocalizedStringResource("ERR_SLOT_UNAVAILABLE")
    static let actionChooseDate = LocalizedStringResource("ACTION_CHOOSE_DATE")
    static let actionChooseDistrict = LocalizedStringResource("ACTION_CHOOSE_DISTRICT")
    static let actionChooseSlot = LocalizedStringResource("ACTION_CHOOSE_SLOT")

    /// Fills the `%` placeholders of a catalog text.
    static func format(_ resource: LocalizedStringResource, _ arguments: CVarArg...) -> String {
        String(format: String(localized: resource), arguments: arguments)
    }
}
