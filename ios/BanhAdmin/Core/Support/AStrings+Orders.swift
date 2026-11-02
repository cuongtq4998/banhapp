import Foundation

/// Order process names and actions (docs/design/admin-orders/13). One constant per key.
extension AStrings {
    static let statusReceived = LocalizedStringResource("A_STATUS_RECEIVED")
    static let statusProcessing = LocalizedStringResource("A_STATUS_PROCESSING")
    static let statusScheduled = LocalizedStringResource("A_STATUS_SCHEDULED")
    static let statusDelivering = LocalizedStringResource("A_STATUS_DELIVERING")
    static let statusFinished = LocalizedStringResource("A_STATUS_FINISHED")

    static let processOrder = LocalizedStringResource("A_PROCESS_ORDER")
    static let scheduleDate = LocalizedStringResource("A_SCHEDULE_DATE")
    static let changeDate = LocalizedStringResource("A_CHANGE_DATE")
    static let startDelivery = LocalizedStringResource("A_START_DELIVERY")
    static let finishOrder = LocalizedStringResource("A_FINISH_ORDER")
    static let finishBody = LocalizedStringResource("A_FINISH_BODY")
    static let finishYes = LocalizedStringResource("A_FINISH_YES")
    static let cancelBlocked = LocalizedStringResource("A_CANCEL_BLOCKED")
    static let fFeeEstimate = LocalizedStringResource("A_F_FEE_ESTIMATE")
    static let feeEffectEstimate = LocalizedStringResource("A_FEE_EFFECT_ESTIMATE")

    /// The label of a status; the three middle steps each have their own name.
    static func status(_ status: OrderStatus) -> LocalizedStringResource {
        switch status {
        case .received, .unknown: statusReceived
        case .processing: statusProcessing
        case .deliveryDateScheduled: statusScheduled
        case .deliveryStarted: statusDelivering
        case .finished: statusFinished
        case .cancelled: statusCancelled
        }
    }
}
