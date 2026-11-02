import BanhCore
import BanhDesign
import SwiftUI

/// Requested date, and the expected date that opens the date sheet when the server allows it.
struct DeliveryDates: View {
    let detail: OrderDetail
    let model: OrderDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let requested = detail.requestedDeliveryDate {
                Text(verbatim: "\(String(localized: AStrings.requestedDate)): \(AdminFormatting.weekdayAndDate(requested))")
                    .textStyle(Typography.body).accessibilityIdentifier(AdminID.orderRequestedDate)
            }
            if let expected = detail.expectedDeliveryDate {
                let text = "\(String(localized: AStrings.expectedDate)): \(AdminFormatting.weekdayAndDate(expected))"
                if detail.allows(.changeDate) {
                    Button { model.openChangeDateSheet() } label: {
                        Label { Text(verbatim: text) } icon: { Image(systemName: "calendar") }
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    }
                    .accessibilityIdentifier(AdminID.orderExpectedDate)
                } else {
                    Text(verbatim: text).accessibilityIdentifier(AdminID.orderExpectedDate)
                }
            }
        }
        .textStyle(Typography.bodyStrong)
    }
}

/// Fee row, correct-fee button, and the amount to collect only when the server sends it.
struct FeeRows: View {
    let detail: OrderDetail
    let model: OrderDetailViewModel

    var body: some View {
        row(AStrings.cakesTotal, MoneyFormatter.format(detail.itemsSubtotalVnd), AdminID.detailTotal)
        row(AStrings.fee, feeText, AdminID.orderFee)
        if let estimate = detail.deliveryFeeEstimateVnd, detail.deliveryFeeFinalVnd == nil {
            Text(verbatim: AStrings.feeEstimateLine(amount: MoneyFormatter.format(estimate)))
                .textStyle(Typography.caption).foregroundStyle(Palette.textSecondary)
                .accessibilityIdentifier(AdminID.orderFeeEstimate)
        }
        if detail.allows(.correctFee) {
            Button(String(localized: AStrings.feeCorrect)) { model.openCorrectFeeSheet() }
                .frame(minHeight: 48).accessibilityIdentifier(AdminID.orderFeeCorrect)
        }
        if let collect = detail.amountToCollectVnd {
            row(AStrings.totalCollect, MoneyFormatter.format(collect), AdminID.orderTotalCollect, strong: true)
        }
    }

    private var feeText: String {
        guard let fee = detail.deliveryFeeFinalVnd else { return String(localized: AStrings.feePending) }
        return fee == 0 ? String(localized: AStrings.feeFree) : MoneyFormatter.format(fee)
    }

    private func row(_ title: LocalizedStringResource, _ value: String, _ identifier: String, strong: Bool = false) -> some View {
        HStack { Text(title); Spacer(); Text(verbatim: value) }
            .textStyle(strong ? Typography.bodyStrong : Typography.body)
            .accessibilityElement(children: .combine).accessibilityIdentifier(identifier)
    }
}

/// Every fee correction, newest last as the server sends it.
struct FeeHistoryCard: View {
    let detail: OrderDetail

    var body: some View {
        if !detail.feeCorrections.isEmpty {
            GlassCard(cornerRadius: Radius.card) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(AStrings.feeHistory).textStyle(Typography.caption).foregroundStyle(Palette.textSecondary)
                    ForEach(Array(detail.feeCorrections.enumerated()), id: \.offset) { index, change in
                        Text(verbatim: "\(AStrings.feeChange(old: MoneyFormatter.format(change.oldFeeVnd), new: MoneyFormatter.format(change.newFeeVnd))) · \(change.changedByName ?? String(localized: AStrings.histCustomer)) · \(AdminFormatting.dateTime(change.changedAt))")
                            .textStyle(Typography.body).accessibilityIdentifier(AdminID.orderFeeHistoryRow(index))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .contain).accessibilityIdentifier(AdminID.orderFeeHistory)
        }
    }
}
