import BanhDesign
import SwiftUI

/// The five steps of an order; Cancelled is outside the line and shows no stepper.
nonisolated enum OrderStep {
    static let order: [OrderStatus] = [.received, .processing, .deliveryDateScheduled, .deliveryStarted, .finished]

    /// 1-based position of a status, nil for Cancelled and unknown names.
    static func number(of status: OrderStatus) -> Int? { order.firstIndex(of: status).map { $0 + 1 } }
}

/// Vertical list of the five steps: done, current (named by text) and next.
struct OrderStepper: View {
    let status: OrderStatus

    var body: some View {
        if let current = OrderStep.number(of: status) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(Array(OrderStep.order.enumerated()), id: \.offset) { index, step in
                    row(number: index + 1, step: step, current: current)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AdminID.stepper)
        }
    }

    private func row(number: Int, step: OrderStatus, current: Int) -> some View {
        let state = number < current ? AStrings.stepDone : number == current ? AStrings.stepCurrent : AStrings.stepNext
        let name = String(localized: AStrings.status(step))
        return HStack(spacing: Spacing.sm) {
            Image(systemName: number < current ? "checkmark.circle.fill" : number == current ? "circle.inset.filled" : "circle")
                .foregroundStyle(number > current ? Palette.textSecondary : Palette.primary)
            Text(verbatim: name).textStyle(number == current ? Typography.bodyStrong : Typography.body)
                .foregroundStyle(number > current ? Palette.textSecondary : Palette.textPrimary)
            if number == current { Text(state).textStyle(Typography.caption).foregroundStyle(Palette.primary) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: AStrings.stepA11y(number: number, name: name, state: String(localized: state))))
        .accessibilityIdentifier(AdminID.step(number))
    }
}
