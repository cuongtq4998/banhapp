import SwiftUI

/// S-6, step 2 of 4: the receiving date and time slot.
struct DateStepView: View {
    @State var model: DateViewModel
    let onNext: () -> Void
    /// Back to S-5 to lower the quantities when no date has room (`DATE_EMPTY_ACTION`).
    let onEditCakes: () -> Void

    var body: some View {
        OrderStepScaffold(step: .date, title: OrderStrings.step2) {
            content
        } bar: {
            ActionButton(title: OrderStrings.commonNext, action: onNext)
                .disabled(!model.canContinue)
                .accessibilityIdentifier(AccessibilityID.orderNext)
        }
        .task { await model.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.availability {
        case .loading:
            VStack(spacing: Spacing.cardGap) {
                SkeletonBlock(cornerRadius: Radius.card).frame(height: Size.logoLarge * 2)
                SkeletonBlock(cornerRadius: Radius.card).frame(height: Size.logoLarge)
            }
            .loadingAnnouncement(identifier: AccessibilityID.dateLoading)
        case .failed(let failure):
            ErrorStateView(message: Strings.catalogLoadFailure(failure, screenMessage: OrderStrings.dateError)) {
                Task { await model.load() }
            }
        case .ready:
            ready
        }
    }

    private var ready: some View {
        VStack(alignment: .leading, spacing: Spacing.cardGap) {
            if model.dateWasCleared {
                InlineMessage(kind: .error, text: String(localized: OrderStrings.dateCleared))
                    .accessibilityIdentifier(AccessibilityID.dateClearedNotice)
            }
            GlassCard {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(OrderStrings.dateTitle)
                        .textStyle(Typography.heading)
                        .foregroundStyle(Palette.textPrimary)
                    if let hint = model.rangeHint {
                        Text(verbatim: hint)
                            .textStyle(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                            .accessibilityIdentifier(AccessibilityID.dateRangeHint)
                    }
                    if let month = model.shownMonth { DateGrid(model: model, month: month) }
                    Text(OrderStrings.dateLegendFull)
                        .textStyle(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            if model.hasNoSelectableDate {
                InlineMessage(
                    kind: .error, text: String(localized: OrderStrings.dateEmpty),
                    actionTitle: OrderStrings.dateEmptyAction, action: onEditCakes,
                    actionIdentifier: AccessibilityID.dateEmptyAction
                )
                .accessibilityIdentifier(AccessibilityID.dateEmptyNotice)
            }
            GlassCard {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(OrderStrings.timeTitle)
                        .textStyle(Typography.heading)
                        .foregroundStyle(Palette.textPrimary)
                    SlotList(model: model)
                }
            }
            if !model.canContinue {
                Text(OrderStrings.nextHintDateTime)
                    .textStyle(Typography.body)
                    .foregroundStyle(Palette.textSecondary)
                    .accessibilityIdentifier(AccessibilityID.dateNextHint)
            }
        }
    }
}
