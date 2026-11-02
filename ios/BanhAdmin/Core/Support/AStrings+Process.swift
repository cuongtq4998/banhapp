import Foundation

/// Stepper, date sheet and fee sheets (docs/design/admin-orders/13). One constant per key.
extension AStrings {
    static let requestedDate = LocalizedStringResource("A_REQUESTED_DATE")
    static let expectedDate = LocalizedStringResource("A_EXPECTED_DATE")
    static let cakesTotal = LocalizedStringResource("A_CAKES_TOTAL")
    static let feePending = LocalizedStringResource("A_FEE_PENDING")
    static let feeFree = LocalizedStringResource("A_FEE_FREE")
    static let totalCollect = LocalizedStringResource("A_TOTAL_COLLECT")
    static let stepCurrent = LocalizedStringResource("A_STEP_CURRENT")
    static let stepDone = LocalizedStringResource("A_STEP_DONE")
    static let stepNext = LocalizedStringResource("A_STEP_NEXT")
    static let scheduleHelp = LocalizedStringResource("A_SCHEDULE_HELP")
    static let scheduleSave = LocalizedStringResource("A_SCHEDULE_SAVE")
    static let rescheduleSave = LocalizedStringResource("A_RESCHEDULE_SAVE")
    static let dateSaved = LocalizedStringResource("A_DATE_SAVED")
    static let feeBody = LocalizedStringResource("A_FEE_BODY")
    static let fRealFee = LocalizedStringResource("A_F_REAL_FEE")
    static let errFeeRequired = LocalizedStringResource("A_ERR_FEE_REQUIRED")
    static let errFeeRange = LocalizedStringResource("A_ERR_FEE_RANGE")
    static let errDatePast = LocalizedStringResource("A_ERR_DATE_PAST")
    static let errDateTooFar = LocalizedStringResource("A_ERR_DATE_TOO_FAR")
    static let feeCorrect = LocalizedStringResource("A_FEE_CORRECT")
    static let feePrevious = LocalizedStringResource("A_FEE_PREVIOUS")
    static let feeCorrectSave = LocalizedStringResource("A_FEE_CORRECT_SAVE")
    static let errFeeSame = LocalizedStringResource("A_ERR_FEE_SAME")
    static let feeHistory = LocalizedStringResource("A_FEE_HISTORY")
    static let feeCorrected = LocalizedStringResource("A_FEE_CORRECTED")

    static func stepA11y(number: Int, name: String, state: String) -> String {
        fill(LocalizedStringResource("A_STEP_A11Y"), [String(number), name, state])
    }
    static func scheduleTitle(code: String, change: Bool) -> String {
        fill(LocalizedStringResource(change ? "A_RESCHEDULE_TITLE" : "A_SCHEDULE_TITLE"), [code])
    }
    static func feeTitle(code: String) -> String { fill(LocalizedStringResource("A_FEE_TITLE"), [code]) }
    static func feeFixTitle(code: String) -> String { fill(LocalizedStringResource("A_FEE_CORRECT_TITLE"), [code]) }
    static func startDeliveryConfirm(code: String) -> String { fill(LocalizedStringResource("A_START_DELIVERY_CONFIRM"), [code]) }
    static func feeEstimateLine(amount: String) -> String { fill(LocalizedStringResource("A_FEE_ESTIMATE_LINE"), [amount]) }
    static func dateLimit(first: String, last: String) -> String { fill(LocalizedStringResource("A_DATE_LIMIT_HELP"), [first, last]) }
    static func feeChange(old: String, new: String) -> String { fill(LocalizedStringResource("A_FEE_CHANGE_LINE"), [old, new]) }
    static func feeConflict(fee: String) -> String { fill(LocalizedStringResource("A_FEE_CONFLICT"), [fee]) }
}
