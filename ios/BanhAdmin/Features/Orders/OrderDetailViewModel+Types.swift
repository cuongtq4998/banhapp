import BanhCore
import Foundation

extension OrderDetailViewModel {
    enum State: Equatable {
        case loading
        case loaded(OrderDetail)
        /// 404: unknown order, or finished more than 90 days ago (AC-21).
        case gone
        case failed(LoadFailure)
    }

    enum Action: Equatable { case process, scheduleDelivery, startDelivery, finish, cancel, changeDate, correctFee }

    /// The text above the action bar after a refused or failed action.
    enum ActionMessage: Equatable {
        case conflict(OrderStatus)
        case failed
        case offline
    }
}

extension OrderDetailViewModel {
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
