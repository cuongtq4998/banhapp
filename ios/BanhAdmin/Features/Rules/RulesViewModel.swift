import BanhCore
import Foundation
import Observation

/// S-A9 Ordering: daily limit, days of notice, minimum cakes (FR-22, BR-11). Lowering the limit below
/// cakes already accepted asks the server which dates are affected first (AC-35); saving cancels nothing.
@Observable
final class RulesViewModel {
    private(set) var load: Load<OrderingRules> = .loading
    var limit = ""
    var lead = ""
    var minimum = ""
    private(set) var errors: [String: String] = [:]
    var banner: String?
    var focusRequest: String?
    var showsDiscard = false
    private(set) var isBusy = false
    /// Dates the new limit leaves over the limit: asked before saving (`warning`) or returned by the save (`result`).
    private(set) var warning: [OverLimitDate]?
    private(set) var result: [OverLimitDate]?
    private var original: OrderingRules?
    private let api: any OwnerAPI
    private let flash: (String) -> Void
    private let done: () -> Void

    init(api: any OwnerAPI, flash: @escaping (String) -> Void, done: @escaping () -> Void) {
        self.api = api
        self.flash = flash
        self.done = done
    }

    func loadRules() async {
        do {
            let rules = try await api.settings().ordering
            original = rules
            limit = String(rules.dailyLimit)
            lead = String(rules.leadDays)
            minimum = String(rules.minQty)
            load = .ready(rules)
        } catch {
            if !(error is SessionEnded) { load = .failed(error.loadFailure) }
        }
    }

    func retryLoad() async {
        load = .loading
        await loadRules()
    }

    var isDirty: Bool {
        guard let original else { return false }
        return FieldRules.number(limit) != original.dailyLimit || FieldRules.number(lead) != original.leadDays
            || FieldRules.number(minimum) != original.minQty
    }

    var canSave: Bool { isDirty && !isBusy }

    @discardableResult
    func validate() -> Bool {
        var found: [String: String] = [:]
        if let text = FieldRules.integer(limit, AStrings.fLimit, range: 1...9999) { found["daily_limit"] = text }
        if let text = FieldRules.integer(lead, AStrings.fLead, range: 0...14) { found["lead_days"] = text }
        if let text = FieldRules.integer(minimum, AStrings.fMin, range: 1...20) {
            found["min_qty"] = text
        } else if let min = FieldRules.number(minimum), let limit = FieldRules.number(limit), min > limit {
            found["min_qty"] = AStrings.errMinAboveLimit(AStrings.fMin)
        }
        errors = found
        let order = [("daily_limit", AdminOwnerID.rulesLimit), ("lead_days", AdminOwnerID.rulesLead), ("min_qty", AdminOwnerID.rulesMin)]
        focusRequest = order.first { found[$0.0] != nil }?.1
        return found.isEmpty
    }

    func save() async {
        banner = nil
        guard validate(), let original, let newLimit = FieldRules.number(limit) else { return }
        if newLimit < original.dailyLimit {
            isBusy = true
            defer { isBusy = false }
            do {
                let impact = try await api.impact(dailyLimit: newLimit)
                if impact.count > 0 { return warning = impact.overLimit }
            } catch {
                return fail(error)
            }
        }
        await send()
    }

    /// "Save anyway" of the warning.
    func confirmWarning() async {
        let shown = warning
        warning = nil
        await send(previewed: shown)
    }

    func dismissWarning() { warning = nil }

    private func send(previewed: [OverLimitDate]? = nil) async {
        guard let newLimit = FieldRules.number(limit), let lead = FieldRules.number(lead), let min = FieldRules.number(minimum) else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let saved = try await api.saveOrdering(dailyLimit: newLimit, leadDays: lead, minQty: min)
            // The list true at save time; shown only when it is not the one the owner already confirmed.
            if !saved.overLimit.isEmpty, saved.overLimit != previewed { return result = saved.overLimit }
            finish()
        } catch {
            fail(error)
        }
    }

    func closeResult() {
        result = nil
        finish()
    }

    private func finish() {
        flash(String(localized: AStrings.saved))
        done()
    }

    private func fail(_ error: Error) {
        guard !(error is SessionEnded) else { return }
        if let failure = error as? APIError, failure.code == "VALIDATION_FAILED", !failure.fieldProblems.isEmpty {
            var found: [String: String] = [:]
            for problem in failure.fieldProblems {
                switch problem.field {
                case "daily_limit": found["daily_limit"] = FieldRules.server(problem, AStrings.fLimit, range: 1...9999)
                case "lead_days": found["lead_days"] = FieldRules.server(problem, AStrings.fLead, range: 0...14)
                case "min_qty":
                    found["min_qty"] = problem.code == "MIN_QTY_OUT_OF_RANGE"
                        ? AStrings.errMinAboveLimit(AStrings.fMin) : FieldRules.server(problem, AStrings.fMin, range: 1...20)
                default: banner = String(localized: AStrings.errGeneric)
                }
            }
            errors = found
            return
        }
        banner = error.saveMessage
    }
}
