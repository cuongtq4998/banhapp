import BanhDesign
import SwiftUI

extension OrderStatus {
    /// From the hand-over of the date on, a cancel would leave cakes without a receiver.
    var blocksCancel: Bool { self == .deliveryDateScheduled || self == .deliveryStarted }
}

/// The bottom bar: only the actions the server allows. Change date and correct fee sit on their rows.
struct ActionBar: View {
    @Bindable var model: OrderDetailViewModel
    let detail: OrderDetail

    var body: some View {
        if detail.allows(.cancel) || forwardAction != nil {
            AdaptiveStack(spacing: Spacing.md) {
                if detail.allows(.cancel) {
                    ActionButton(title: AStrings.cancelOrder, emphasis: .destructive) { model.showsCancelSheet = true }
                        .disabled(model.isBusy)
                        .accessibilityIdentifier(AdminID.detailCancel)
                }
                if let forward = forwardAction {
                    ActionButton(title: forward.title, showsProgress: model.running == forward.running, action: forward.run)
                        .disabled(model.isBusy)
                        .accessibilityIdentifier(forward.identifier)
                }
            }
        }
    }

    private struct Forward {
        let title: LocalizedStringResource
        let identifier: String
        let running: OrderDetailViewModel.Action
        let run: () -> Void
    }

    private var forwardAction: Forward? {
        if detail.allows(.process) {
            return Forward(title: AStrings.processOrder, identifier: AdminID.orderProcess, running: .process) { Task { await model.process() } }
        }
        if detail.allows(.scheduleDelivery) {
            return Forward(title: AStrings.scheduleDate, identifier: AdminID.orderSchedule, running: .scheduleDelivery) { model.openScheduleSheet() }
        }
        if detail.allows(.startDelivery) {
            return Forward(title: AStrings.startDelivery, identifier: AdminID.orderStartDelivery, running: .startDelivery) { model.openStartDeliverySheet() }
        }
        if detail.allows(.finish) {
            return Forward(title: AStrings.finishOrder, identifier: AdminID.orderFinish, running: .finish) { model.showsFinishDialog = true }
        }
        return nil
    }
}
