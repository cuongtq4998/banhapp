import BanhCore
import BanhDesign
import SwiftUI

/// S-A15 Start delivery with the real fee, and S-A16 Correct the fee; one layout, two modes.
struct FeeSheet: View {
    @Bindable var model: OrderDetailViewModel
    @FocusState private var focus: String?
    @Environment(\.dismiss) private var dismiss

    private var correcting: Bool { model.feeEntry?.previous != nil }
    private var ids: (sheet: String, field: String, error: String, total: String, save: String, back: String) {
        correcting
            ? (AdminID.feeFixSheet, AdminID.feeFixField, AdminID.feeFixError, AdminID.feeFixTotal, AdminID.feeFixSave, AdminID.feeFixBack)
            : (AdminID.feeSheet, AdminID.feeField, AdminID.feeError, AdminID.feeTotal, AdminID.feeConfirm, AdminID.feeBack)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(verbatim: correcting ? AStrings.feeFixTitle(code: model.code) : AStrings.feeTitle(code: model.code))
                    .textStyle(Typography.heading).foregroundStyle(Palette.textPrimary).accessibilityAddTraits(.isHeader)
                if let previous = model.feeEntry?.previous {
                    Text(verbatim: "\(String(localized: AStrings.feePrevious)): \(MoneyFormatter.format(previous))")
                        .textStyle(Typography.bodyStrong).accessibilityIdentifier(AdminID.feeFixPrevious)
                } else {
                    Text(AStrings.feeBody).textStyle(Typography.body).foregroundStyle(Palette.textSecondary)
                }
                FormTextField(
                    label: AStrings.fRealFee, text: text, identifier: ids.field, error: fieldError,
                    errorIdentifier: ids.error, keyboard: .numberPad, focus: $focus
                )
                preview
            }
            .padding(Spacing.lg)
        }
        .bottomActionBar {
            VStack(spacing: Spacing.sm) {
                ActionButton(
                    verbatim: correcting ? String(localized: AStrings.feeCorrectSave) : AStrings.startDeliveryConfirm(code: model.code),
                    showsProgress: model.running == .startDelivery || model.running == .correctFee
                ) { Task { await correcting ? model.correctFee() : model.startDelivery() } }
                .disabled(model.isBusy || !(model.feeEntry?.canSave ?? false))
                .accessibilityIdentifier(ids.save)
                ActionButton(title: AStrings.back, emphasis: .secondary) { dismiss() }
                    .accessibilityIdentifier(ids.back)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .background(Palette.surfaceSolid.ignoresSafeArea())
        .accessibilityIdentifier(ids.sheet)
        .onAppear { focus = ids.field }
    }

    private var text: Binding<String> {
        Binding(get: { model.feeEntry?.text ?? "" }, set: { model.feeEntry?.text = $0 })
    }

    /// The live total lives only here; the detail page shows a total only from the server.
    @ViewBuilder
    private var preview: some View {
        if let entry = model.feeEntry, let total = entry.preview {
            let value = entry.fee == 0 ? String(localized: AStrings.feeFree) : MoneyFormatter.format(total)
            Text(verbatim: "\(String(localized: AStrings.totalCollect)): \(value)").textStyle(Typography.bodyStrong)
                .accessibilityValue(Text(verbatim: value)).accessibilityIdentifier(ids.total)
        }
    }

    private var fieldError: String? {
        switch model.entryError {
        case .feeRequired?: String(localized: AStrings.errFeeRequired)
        case .feeInvalid?: String(localized: AStrings.errFeeRange)
        case .feeUnchanged?: String(localized: AStrings.errFeeSame)
        default:
            model.feeEntry.flatMap { $0.text.isEmpty || $0.isValid ? nil : String(localized: AStrings.errFeeRange) }
        }
    }
}
