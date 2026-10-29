import SwiftUI

/// S-5, step 1 of 4: choose a quantity for each active cake.
struct CakesStepView: View {
    private static let skeletonRows = 3

    @State var model: CakesViewModel
    let onNext: () -> Void

    var body: some View {
        OrderStepScaffold(step: .cakes, title: Strings.step1) {
            content
        } bar: {
            ActionButton(title: OrderStrings.commonNext, action: onNext)
                .disabled(!model.canContinue)
                .accessibilityIdentifier(AccessibilityID.orderNext)
        }
        .task { await model.load() }
        .onDisappear { model.leave() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.rows {
        case .loading:
            VStack(spacing: Spacing.cardGap) {
                ForEach(0..<Self.skeletonRows, id: \.self) { _ in
                    SkeletonBlock(cornerRadius: Radius.card).frame(height: Size.thumb)
                }
            }
            .loadingAnnouncement(identifier: AccessibilityID.homeSkeleton)
        case .failed(let failure):
            ErrorStateView(message: Strings.catalogLoadFailure(failure, screenMessage: Strings.productsError)) {
                Task { await model.load() }
            }
        case .ready(let rows) where rows.isEmpty:
            ErrorStateView(message: OrderStrings.productsEmpty, identifier: AccessibilityID.emptyState) {
                Task { await model.load() }
            }
        case .ready(let rows):
            ready(rows)
        }
    }

    private func ready(_ rows: [CakesViewModel.Row]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.cardGap) {
            ForEach(model.removedCakeNames, id: \.self) { name in
                InlineMessage(kind: .info, text: OrderStrings.format(OrderStrings.cakeRemoved, name))
                    .accessibilityIdentifier(AccessibilityID.orderCakeRemovedNotice)
            }
            GlassCard(padding: Spacing.md) {
                VStack(spacing: Spacing.md) {
                    ForEach(rows) { row in CakeRow(row: row, model: model) }
                }
            }
            summary
            if model.showsMinHint {
                InlineMessage(kind: .info, text: OrderStrings.format(OrderStrings.qtyMinHint, model.minQty))
                    .accessibilityIdentifier(AccessibilityID.qtyMinHint)
            }
        }
    }

    private var summary: some View {
        GlassCard(padding: Spacing.inner) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(verbatim: OrderStrings.format(OrderStrings.qtyTotal, model.totalCakes))
                    .textStyle(Typography.cardTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityIdentifier(AccessibilityID.qtyTotal)
                Text(verbatim: OrderStrings.format(OrderStrings.qtySubtotal, model.subtotalText))
                    .textStyle(Typography.body)
                    .foregroundStyle(Palette.primaryDeep)
                    .accessibilityIdentifier(AccessibilityID.qtySubtotal)
            }
        }
    }
}

private struct CakeRow: View {
    let row: CakesViewModel.Row
    let model: CakesViewModel
    @ScaledMetric(relativeTo: .body) private var thumbSize = Size.thumb * 0.75

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.md) { picture; details; stepper }
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.md) { picture; details }
                stepper
            }
        }
    }

    private var picture: some View {
        ProductImage(url: row.imageURL, accessibilityName: row.name)
            .frame(width: thumbSize, height: thumbSize)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(verbatim: row.name)
                .textStyle(Typography.cardTitle)
                .foregroundStyle(Palette.textPrimary)
            Text(verbatim: Strings.priceEach(amount: row.priceText))
                .textStyle(Typography.body)
                .fontWeight(.semibold)
                .foregroundStyle(Palette.primaryDeep)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stepper: some View {
        QuantityStepper(
            productID: row.id.identifierText, name: row.name, value: row.quantity,
            canDecrease: row.canDecrease, canIncrease: row.canIncrease,
            decrease: { model.decrease(row) }, increase: { model.increase(row) }
        )
    }
}
