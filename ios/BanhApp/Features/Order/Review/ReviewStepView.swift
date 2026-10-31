import SwiftUI

/// S-8, step 4 of 4: the full order, with a way back to each part and the confirm button.
struct ReviewStepView: View {
    let model: ReviewViewModel
    let privacy: PrivacyLink
    let onEdit: (OrderStep) -> Void

    var body: some View {
        OrderStepScaffold(step: .review, title: OrderStrings.step4, backEnabled: !model.isSending,
                          scrollToTop: model.noticeCount) {
            content
                // The whole review is inert while the order is being sent (AC-19).
                .disabled(model.isSending)
        } bar: {
            ActionButton(
                title: model.isSending ? SendStrings.sending : OrderStrings.confirm,
                showsProgress: model.isSending
            ) { Task { await model.confirm() } }
                .disabled(!model.canConfirm)
                .accessibilityIdentifier(AccessibilityID.reviewConfirm)
        }
        .privacyPage(privacy)
        .onChange(of: model.fieldsRejected) { _, rejected in
            guard rejected else { return }
            model.fieldRejectionHandled()
            onEdit(.recipient)
        }
    }

    private func edit(_ step: OrderStep) {
        model.edit()
        onEdit(step)
    }

    @ViewBuilder
    private var content: some View {
        switch model.summary {
        case .loading:
            SkeletonBlock(cornerRadius: Radius.card).frame(height: Size.logoLarge * 2)
                .loadingAnnouncement(identifier: AccessibilityID.homeSkeleton)
        case .failed(let failure):
            ErrorStateView(message: Strings.catalogLoadFailure(failure, screenMessage: Strings.productsError)) {
                Task { await model.refresh() }
            }
        case .ready(let summary):
            ready(summary)
        }
    }

    private func ready(_ summary: ReviewViewModel.Summary) -> some View {
        VStack(alignment: .leading, spacing: Spacing.cardGap) {
            banner
            
            cakesCard(summary)
            deliveryCard(summary)
            Text(OrderStrings.reviewPrivacy)
                .textStyle(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
                .accessibilityIdentifier(AccessibilityID.reviewPrivacy)
            PrivacyTextLink(
                title: OrderStrings.reviewPrivacyLink, identifier: AccessibilityID.reviewPrivacyLink, action: privacy.open
            )
            .disabled(model.isSending)
        }
    }

    @ViewBuilder
    private var banner: some View {
        if let notice = model.notice {
            InlineMessage(
                kind: notice.kind == .priceChanged ? .info : .error, text: notice.message,
                actionTitle: notice.actionTitle,
                action: {
                    if let step = notice.fixStep { edit(step) } else { Task { await model.confirm() } }
                },
                actionIdentifier: AccessibilityID.reviewMessageAction
            )
            .accessibilityIdentifier(AccessibilityID.reviewMessage)
        } else if let blocker = model.blocker {
            InlineMessage(
                kind: .error, text: blocker.message, actionTitle: blocker.actionTitle,
                action: { edit(blocker.step) }, actionIdentifier: AccessibilityID.reviewMessageAction
            )
            .accessibilityIdentifier(AccessibilityID.reviewMessage)
        }
    }

    private func cakesCard(_ summary: ReviewViewModel.Summary) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(OrderStrings.reviewCakes)
                    .textStyle(Typography.heading)
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                editable(.cakes, identifier: AccessibilityID.reviewEditCakes) {
                    ForEach(summary.lines, id: \.productID) { line in
                        SummaryRow(
                            label: OrderStrings.format(OrderStrings.reviewItem, line.name, line.quantity),
                            value: MoneyFormatter.format(line.lineTotalVND),
                            highlighted: model.highlight.productIDs.contains(line.productID),
                            identifier: AccessibilityID.reviewItem(line.productID.identifierText)
                        )
                    }
                }
                Divider()
                SummaryRow(label: OrderStrings.reviewFee, value: summary.feeText, highlighted: model.highlight.fee,
                           identifier: AccessibilityID.reviewFee)
                SummaryRow(label: OrderStrings.reviewTotal, value: summary.totalText, emphasized: true,
                           highlighted: model.highlight.total, identifier: AccessibilityID.reviewTotal)
            }
        }
    }

    private func deliveryCard(_ summary: ReviewViewModel.Summary) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                editable(.date, identifier: AccessibilityID.reviewEditDate) {
                    SummaryRow(label: OrderStrings.reviewDate, value: summary.dateText, identifier: AccessibilityID.reviewDate)
                    SummaryRow(label: OrderStrings.reviewTime, value: summary.timeText, identifier: AccessibilityID.reviewTime)
                }
                Divider()
                editable(.recipient, identifier: AccessibilityID.reviewEditRecipient) {
                    SummaryRow(label: OrderStrings.reviewName, value: summary.name, identifier: AccessibilityID.reviewName)
                    SummaryRow(label: OrderStrings.reviewPhone, value: summary.phone, identifier: AccessibilityID.reviewPhone)
                    SummaryRow(label: OrderStrings.reviewAddress, value: summary.address, identifier: AccessibilityID.reviewAddress)
                    if let note = summary.note {
                        SummaryRow(label: OrderStrings.reviewNote, value: note, identifier: AccessibilityID.reviewNote)
                    }
                }
            }
        }
    }

    /// A group of rows with the `COMMON_EDIT` control that opens the step holding their data.
    private func editable<Rows: View>(
        _ step: OrderStep, identifier: String, @ViewBuilder rows: () -> Rows
    ) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.md) { rows() }
            Button { edit(step) } label: {
                Text(OrderStrings.commonEdit)
                    .textStyle(Typography.contactButton)
                    .foregroundStyle(Palette.primaryDeep)
                    .frame(minWidth: Size.touchTarget, minHeight: Size.touchTarget)
            }
            .accessibilityIdentifier(identifier)
        }
    }
}
