import BanhCore
import BanhDesign
import SwiftUI

/// The cards of S-A4 below the title: customer, delivery, cakes, note, cancel reason, two small lines.
struct DetailCards: View {
    let detail: OrderDetail
    let due: DueState?
    let opener: any URLOpener
    @Binding var toast: String?
    let model: OrderDetailViewModel

    var body: some View {
        VStack(spacing: Spacing.md) {
            customer
            delivery
            cakes
            if let note = detail.note, !note.isEmpty {
                card(AStrings.secNote, identifier: AdminID.detailNote) { selectable(note) }
            }
            if let reason = detail.cancelReason {
                card(AStrings.secReason, identifier: AdminID.detailReason) { Text(verbatim: reasonText(reason)).textStyle(Typography.body) }
            }
            FeeHistoryCard(detail: detail)
            footerLines
        }
    }

    private var customer: some View {
        card(AStrings.secCustomer, identifier: AdminID.detailCustomer) {
            Text(verbatim: detail.customerName).textStyle(Typography.bodyStrong)
            selectable(detail.customerPhone).accessibilityIdentifier(AdminID.detailPhone)
            AdaptiveStack(spacing: Spacing.sm) {
                ActionButton(verbatim: AStrings.call(phone: detail.customerPhone), systemImage: "phone.fill", emphasis: .secondary) {
                    Task { await open(ContactLinks.phoneURL(detail.customerPhone), failure: nil) }
                }
                .accessibilityIdentifier(AdminID.detailCall)
                ActionButton(title: AStrings.zalo, systemImage: "message.fill", emphasis: .secondary) {
                    Task { await open(ContactLinks.zaloURL(detail.customerPhone), failure: String(localized: AStrings.zaloUnavailable)) }
                }
                .accessibilityIdentifier(AdminID.detailZalo)
            }
        }
    }

    private var delivery: some View {
        card(AStrings.secDelivery, identifier: AdminID.detailDelivery) {
            AdaptiveStack(spacing: Spacing.sm) {
                Text(verbatim: "\(AdminFormatting.weekdayAndDate(detail.deliveryDate)) · \(detail.slot.text)")
                    .textStyle(Typography.bodyStrong)
                if let due { DueMark(text: due.text).accessibilityIdentifier(AdminID.detailDue) }
            }
            selectable("\(detail.customerAddress), \(detail.districtName)").accessibilityIdentifier(AdminID.detailAddress)
            DeliveryDates(detail: detail, model: model)
        }
    }

    private var cakes: some View {
        card(AStrings.secCakes, identifier: AdminID.detailCakes) {
            ForEach(Array(detail.items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: "\(item.productName) × \(item.quantity)").textStyle(Typography.body)
                    Spacer()
                    Text(verbatim: MoneyFormatter.format(item.lineTotalVnd)).textStyle(Typography.bodyStrong)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(AdminID.detailCake(index))
            }
            FeeRows(detail: detail, model: model)
        }
    }

    private var footerLines: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(verbatim: AStrings.placedAt(AdminFormatting.dateTime(detail.createdAt)))
            Text(verbatim: AStrings.lastChanged(
                name: detail.lastChange.actorName ?? String(localized: AStrings.histCustomer),
                datetime: AdminFormatting.dateTime(detail.lastChange.at)
            ))
            .accessibilityIdentifier(AdminID.detailLastChanged)
        }
        .textStyle(Typography.caption).foregroundStyle(Palette.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.sm)
    }

    private func card<Content: View>(
        _ title: LocalizedStringResource, identifier: String, @ViewBuilder content: () -> Content
    ) -> some View {
        GlassCard(cornerRadius: Radius.card) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(title).textStyle(Typography.caption).foregroundStyle(Palette.textSecondary)
                content()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private func line(_ title: LocalizedStringResource, _ value: String, _ identifier: String, strong: Bool = false) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(verbatim: value)
        }
        .textStyle(strong ? Typography.bodyStrong : Typography.body)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private func selectable(_ text: String) -> some View {
        Text(verbatim: text).textStyle(Typography.body).textSelection(.enabled)
            .foregroundStyle(Palette.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reasonText(_ wire: String) -> String {
        CancelReason(rawValue: wire).map { String(localized: AStrings.reason($0)) } ?? wire
    }

    private func open(_ url: URL?, failure: String?) async {
        let opened = if let url { await opener.open(url) } else { false }
        if !opened, let failure { toast = failure }
    }
}
