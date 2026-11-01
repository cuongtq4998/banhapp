import BanhCore
import BanhDesign
import SwiftUI

/// S-A9 Ordering.
struct RulesView: View {
    @Bindable var model: RulesViewModel
    let onBack: () -> Void
    @FocusState private var focus: String?

    var body: some View {
        SettingsScaffold(title: String(localized: AStrings.rowRules), screen: AdminOwnerID.rules, onBack: back, showsBar: model.load.value != nil) {
            LoadStateView(load: model.load, screen: AdminOwnerID.rules, retry: { Task { await model.retryLoad() } }) { _ in form }
        } bar: {
            ActionButton(title: AStrings.save, showsProgress: model.isBusy) {
                focus = nil
                Task { await model.save() }
            }
            .disabled(!model.canSave)
            .accessibilityIdentifier(AdminOwnerID.rulesSave)
        }
        .task { await model.loadRules() }
        .onChange(of: model.focusRequest) { _, id in focus = id }
        .discardDialog(isPresented: $model.showsDiscard, discard: onBack)
        .sheet(item: sheetItem) { item in
            switch item {
            case .warning(let list): OverLimitSheet(items: list, confirm: { Task { await model.confirmWarning() } }, back: model.dismissWarning)
            case .result(let list): OverLimitSheet(items: list, confirm: nil, back: model.closeResult)
            }
        }
    }

    /// One sheet for both lists (two `.sheet` modifiers on one view do not both work).
    private var sheetItem: Binding<OverLimitItem?> {
        Binding(
            get: { model.warning.map { .warning($0) } ?? model.result.map { .result($0) } },
            set: { item in
                guard item == nil else { return }
                if model.warning != nil { model.dismissWarning() } else if model.result != nil { model.closeResult() }
            }
        )
    }

    private func back() {
        if model.isDirty { model.showsDiscard = true } else { onBack() }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            if let text = model.banner {
                InlineMessage(kind: .error, text: text).accessibilityIdentifier(AdminOwnerID.saveError)
            }
            GlassCard {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    NumberField(
                        label: AStrings.fLimit, text: $model.limit, identifier: AdminOwnerID.rulesLimit, error: model.errors["daily_limit"],
                        errorIdentifier: AdminOwnerID.fieldError(AdminOwnerID.rules, "daily_limit"), focus: $focus
                    )
                    NumberField(
                        label: AStrings.fLead, text: $model.lead, identifier: AdminOwnerID.rulesLead, error: model.errors["lead_days"],
                        errorIdentifier: AdminOwnerID.fieldError(AdminOwnerID.rules, "lead_days"), focus: $focus
                    )
                    NumberField(
                        label: AStrings.fMin, text: $model.minimum, identifier: AdminOwnerID.rulesMin, error: model.errors["min_qty"],
                        errorIdentifier: AdminOwnerID.fieldError(AdminOwnerID.rules, "min_qty"), focus: $focus
                    )
                    Text(AStrings.horizonFixed).textStyle(Typography.caption).foregroundStyle(Palette.textSecondary)
                }
            }
            Text(AStrings.rulesEffect).textStyle(Typography.caption).foregroundStyle(Palette.textSecondary)
        }
    }
}

enum OverLimitItem: Identifiable, Equatable {
    case warning([OverLimitDate])
    case result([OverLimitDate])

    var id: String {
        switch self {
        case .warning: "warning"
        case .result: "result"
        }
    }
}

/// The dates left over the new daily limit, with "Save anyway" (before saving) or only the list (after).
struct OverLimitSheet: View {
    let items: [OverLimitDate]
    let confirm: (() -> Void)?
    let back: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(AStrings.limitWarnTitle).textStyle(Typography.heading).foregroundStyle(Palette.textPrimary)
                .accessibilityAddTraits(.isHeader).accessibilityIdentifier(AdminOwnerID.rulesWarnDialog)
            Text(verbatim: AStrings.limitWarnBody(count: items.count)).textStyle(Typography.body)
                .foregroundStyle(Palette.textSecondary)
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    ForEach(items, id: \.date) { item in
                        Text(verbatim: "\(AdminFormatting.shortDate(item.date)) (\(item.cakesAccepted) bánh)").textStyle(Typography.bodyStrong)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let confirm {
                ActionButton(title: AStrings.saveAnyway, action: confirm).accessibilityIdentifier(AdminOwnerID.rulesWarnConfirm)
                ActionButton(title: AStrings.back, emphasis: .secondary, action: back).accessibilityIdentifier(AdminOwnerID.rulesWarnBack)
            } else {
                // Second warning: the limit is saved already, nothing is left to go back to.
                ActionButton(title: AStrings.understood, action: back).accessibilityIdentifier(AdminOwnerID.rulesWarnConfirm)
            }
        }
        .padding(Spacing.lg)
        .presentationDetents([.medium, .large])
        .background(Palette.surfaceSolid.ignoresSafeArea())
    }
}
