import BanhCore
import Foundation
import Observation

/// S-A4 and S-A5: one order and the three status actions (FR-14 to FR-19).
@Observable
final class OrderDetailViewModel {
    enum State: Equatable {
        case loading
        case loaded(OrderDetail)
        /// 404: unknown order, or finished more than 90 days ago (AC-21).
        case gone
        case failed(LoadFailure)
    }

    enum Action: Equatable { case confirm, complete, cancel }

    /// The text above the action bar after a refused or failed action.
    enum ActionMessage: Equatable {
        case conflict(OrderStatus)
        case failed
        case offline
    }

    let code: String
    private(set) var state: State = .loading
    private(set) var running: Action?
    private(set) var actionMessage: ActionMessage?
    /// A confirmation sentence for the toast and a counter for the success haptic.
    var toast: String?
    private(set) var successCount = 0
    private(set) var failureCount = 0
    var showsCompleteDialog = false
    var showsCancelSheet = false

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

    func confirm() async { await perform(.confirm, to: .confirmed, reason: nil) }
    func complete() async { showsCompleteDialog = false; await perform(.complete, to: .completed, reason: nil) }
    func cancel(reason: CancelReason) async { await perform(.cancel, to: .cancelled, reason: reason) }

    private func perform(_ action: Action, to target: OrderStatus, reason: CancelReason?) async {
        guard let current = detail, !isBusy else { return }
        running = action
        actionMessage = nil
        defer { running = nil }
        do {
            switch try await api.changeStatus(code: code, expected: current.status, to: target, reason: reason) {
            case .changed(let updated):
                state = .loaded(updated)
                showsCancelSheet = false
                successCount += 1
                toast = String(localized: AStrings.statusChanged)
                onChanged()
            case .conflict(let latest):
                state = .loaded(latest)
                showsCancelSheet = false
                showsCompleteDialog = false
                actionMessage = .conflict(latest.status)
                failureCount += 1
                onChanged()
            }
        } catch {
            guard !(error is SessionEnded) else { return }
            await handle(actionError: error)
        }
    }

    private func handle(actionError error: Error) async {
        let api = error as? APIError
        if api?.isConnectivity == true {
            actionMessage = .offline
        } else if api?.httpStatus == 404 {
            state = .gone
            showsCancelSheet = false
        } else if api?.code == "STATUS_TRANSITION_INVALID" {
            // The pair is no longer allowed: show what the order is now.
            await load()
            if let latest = detail { actionMessage = .conflict(latest.status) }
            showsCancelSheet = false
            failureCount += 1
        } else {
            actionMessage = .failed
        }
    }

    /// The text for `actionMessage`.
    var messageText: String? {
        switch actionMessage {
        case .conflict(let status)?: AStrings.conflict(status: String(localized: AStrings.status(status)))
        case .failed?: String(localized: AStrings.errStatus)
        case .offline?: String(localized: AStrings.offlineSave)
        case nil: nil
        }
    }
}
