import BanhCore
import BanhDesign
import SwiftUI

/// One order in the list: code and status, customer, date and slot with the due mark, cakes, total, district.
/// No phone, address or note (FR-9). Read by VoiceOver as one element.
struct OrderRowView: View {
    let order: OrderSummary
    let due: DueState?

    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text(verbatim: order.orderCode).textStyle(Typography.rowCode).foregroundStyle(Palette.textPrimary)
                    Spacer(minLength: Spacing.sm)
                    StatusBadge(tone: order.status.tone, text: String(localized: AStrings.status(order.status)))
                }
                Text(verbatim: order.customerName).textStyle(Typography.cardTitle).foregroundStyle(Palette.textPrimary)
                AdaptiveStack(spacing: Spacing.sm) {
                    Text(verbatim: AStrings.rowDelivery(date: AdminFormatting.shortDate(order.deliveryDate), slot: order.slot.text))
                        .textStyle(Typography.body).foregroundStyle(Palette.textSecondary)
                    if let due { DueMark(text: due.text).accessibilityIdentifier(AdminID.due(order.orderCode)) }
                }
                Text(verbatim: AStrings.rowMeta(
                    cakes: order.totalCakes, total: MoneyFormatter.format(order.totalVnd), district: order.districtName
                ))
                .textStyle(Typography.bodyStrong).foregroundStyle(Palette.textPrimary)
            }
            Image(systemName: "chevron.right").foregroundStyle(Palette.textSecondary).accessibilityHidden(true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: Radius.cardRow)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text(AStrings.rowHintA11y))
    }
}

extension OrderStatus {
    var tone: StatusBadge.Tone {
        switch self {
        case .received, .unknown: .new
        case .processing, .deliveryDateScheduled, .deliveryStarted: .confirmed
        case .finished: .completed
        case .cancelled: .cancelled
        }
    }
}

extension DueState {
    var text: String {
        switch self {
        case .today: String(localized: AStrings.dueToday)
        case .overdue(let days): AStrings.overdue(days: days)
        }
    }
}

/// Five skeleton rows while the first page loads.
struct OrderListSkeleton: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            ForEach(0..<5, id: \.self) { _ in SkeletonBlock().frame(height: 112) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(AdminID.ordersSkeleton)
    }
}
