import BanhCore
import Foundation
import Observation

/// S-A4 and S-A5: one order and its actions; the buttons come only from `allowed_actions`.
@Observable
final class OrderDetailViewModel {
    let code: String
    private(set) var state: State = .loading
    private(set) var running: Action?
    private(set) var actionMessage: ActionMessage?
    /// The refusal shown inside the open date or fee sheet.
    private(set) var entryError: EntryError?
    /// A confirmation sentence for the toast and a counter for the success haptic.
    var toast: String?
    private(set) var successCount = 0
    private(set) var failureCount = 0
    var showsFinishDialog = false
    var showsCancelSheet = false
    var dateEntry: DateEntry?
    var feeEntry: FeeEntryState?

    private let api: any OrdersAPI
    private let onChanged: () -> Void

    init(code: String, api: any OrdersAPI, onChanged: @escaping () -> Void) {
        self.code = code
        self.api = api
        self.onChanged = onChanged
    }

    var detail: OrderDetail? {
        if case .loaded(let detail) = state { detail } else { nil }
    }

    var isBusy: Bool { running != nil }

    func load() async {
        if detail == nil { state = .loading }
        do {
            state = .loaded(try await api.order(code: code))
        } catch {
            guard !(error is SessionEnded), !Task.isCancelled else { return }
            apply(loadError: error)
        }
    }

    private func apply(loadError error: Error) {
        let api = error as? APIError
        if api?.httpStatus == 404 {
            state = .gone
        } else if detail == nil {
            state = .failed(api?.isConnectivity == true ? .network : .other)
        }
    }

    // MARK: Sheets

    func openScheduleSheet() {
        guard let detail, detail.allows(.scheduleDelivery) else { return }
        entryError = nil
        dateEntry = DateEntry(range: detail.expectedDateRange, current: nil)
    }

    func openChangeDateSheet() {
        guard let detail, detail.allows(.changeDate) else { return }
        entryError = nil
        dateEntry = DateEntry(range: detail.expectedDateRange, current: detail.expectedDeliveryDate)
    }

    func openStartDeliverySheet() {
        guard let detail, detail.allows(.startDelivery) else { return }
        entryError = nil
        feeEntry = FeeEntryState(previous: nil, cakesSubtotalVnd: detail.itemsSubtotalVnd)
    }

    func openCorrectFeeSheet() {
        guard let detail, detail.allows(.correctFee) else { return }
        entryError = nil
        feeEntry = FeeEntryState(previous: detail.deliveryFeeFinalVnd, cakesSubtotalVnd: detail.itemsSubtotalVnd)
    }

    // MARK: Actions

    func process() async { await status(.process, to: .processing) }
    func finish() async { showsFinishDialog = false; await status(.finish, to: .finished) }
    func cancel(reason: CancelReason) async { await status(.cancel, to: .cancelled, reason: reason) }

    func scheduleDelivery() async {
        guard let date = dateEntry, date.canSave else { return }
        await status(.scheduleDelivery, to: .deliveryDateScheduled, date: date.chosen)
    }

    func startDelivery() async {
        guard let entry = feeEntry, entry.canSave, let fee = entry.fee else { return }
        await status(.startDelivery, to: .deliveryStarted, fee: fee)
    }

    func changeDate() async {
        guard let entry = dateEntry, entry.canSave, let previous = entry.current else { return }
        await perform(.changeDate) { try await api.changeExpectedDate(code: code, previous: previous, to: entry.chosen) }
    }

    func correctFee() async {
        guard let entry = feeEntry, entry.canSave, let fee = entry.fee, let previous = entry.previous else { return }
        await perform(.correctFee) { try await api.correctFee(code: code, previous: previous, to: fee) }
    }

    private func status(
        _ action: Action, to target: OrderStatus, reason: CancelReason? = nil, date: String? = nil, fee: Int? = nil
    ) async {
        guard let current = detail else { return }
        let request = StatusRequest(expected: current.status, target: target, reason: reason, expectedDeliveryDate: date, deliveryFeeVnd: fee)
        await perform(action) { try await api.changeStatus(code: code, request) }
    }

    private func perform(_ action: Action, _ call: () async throws -> StatusChangeOutcome) async {
        guard detail != nil, !isBusy else { return }
        running = action
        actionMessage = nil
        entryError = nil
        defer { running = nil }
        do {
            switch try await call() {
            case .changed(let updated):
                state = .loaded(updated)
                closeSheets()
                successCount += 1
                toast = String(localized: AStrings.statusChanged)
                onChanged()
            case .conflict(let latest):
                state = .loaded(latest)
                closeSheets()
                actionMessage = .conflict(latest.status)
                failureCount += 1
                onChanged()
            }
        } catch {
            guard !(error is SessionEnded) else { return }
            await handle(actionError: error)
        }
    }

    private func closeSheets() {
        showsCancelSheet = false
        showsFinishDialog = false
        dateEntry = nil
        feeEntry = nil
    }

    private func handle(actionError error: Error) async {
        let api = error as? APIError
        if api?.isConnectivity == true {
            actionMessage = .offline
        } else if api?.httpStatus == 404 {
            state = .gone
            closeSheets()
        } else if let api, case let refusal = EntryError(api), refusal == .transitionInvalid || refusal == .feeCorrectionNotAllowed {
            // The pair is no longer allowed: show what the order is now.
            await load()
            if let latest = detail { actionMessage = .conflict(latest.status) }
            closeSheets()
            failureCount += 1
        } else if let api, case let refusal = EntryError(api), refusal != .other {
            entryError = refusal
            failureCount += 1
        } else {
            actionMessage = .failed
        }
    }
}
