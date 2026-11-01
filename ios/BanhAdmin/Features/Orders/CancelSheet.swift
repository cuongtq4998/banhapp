import BanhDesign
import SwiftUI

/// S-A5 Cancel order: choose one of four reasons and confirm; nothing is preselected (AC-28).
struct CancelSheet: View {
    @Bindable var model: OrderDetailViewModel
    @State private var reason: CancelReason?
    @Environment(\.dismiss) private var dismiss

    private static let identifiers: [CancelReason: String] = [
        .customerAsked: AdminID.cancelCustomer,
        .cannotDeliver: AdminID.cancelCannotDeliver,
        .cannotReachCustomer: AdminID.cancelNoContact,
        .fakeSpam: AdminID.cancelSpam,
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(AStrings.cancelTitle).textStyle(Typography.heading).foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: AStrings.cancelBody(code: model.code)).textStyle(Typography.body)
                    .foregroundStyle(Palette.textSecondary)
                reasons
                Text(AStrings.reasonInternal).textStyle(Typography.caption).foregroundStyle(Palette.textSecondary)
                if let text = model.messageText, model.actionMessage != nil {
                    InlineMessage(kind: .error, text: text).accessibilityIdentifier(AdminID.cancelError)
                }
            }
            .padding(Spacing.lg)
        }
        .bottomActionBar {
            VStack(spacing: Spacing.sm) {
                ActionButton(
                    verbatim: AStrings.cancelConfirm(code: model.code), emphasis: .destructive,
                    showsProgress: model.running == .cancel
                ) {
                    if let reason { Task { await model.cancel(reason: reason) } }
                }
                .disabled(reason == nil || model.isBusy)
                .accessibilityIdentifier(AdminID.cancelConfirm)
                ActionButton(title: AStrings.back, emphasis: .secondary) { dismiss() }
                    .accessibilityIdentifier(AdminID.cancelBack)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .background(Palette.surfaceSolid.ignoresSafeArea())
    }

    private var reasons: some View {
        VStack(spacing: 0) {
            ForEach(Array(CancelReason.allCases.enumerated()), id: \.element) { index, option in
                Button { reason = option } label: {
                    HStack {
                        Text(AStrings.reason(option)).textStyle(Typography.body).foregroundStyle(Palette.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: reason == option ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(reason == option ? Palette.primary : Palette.textSecondary)
                    }
                    .padding(.horizontal, Spacing.md)
                    .frame(minHeight: 52)
                    .background(reason == option ? Palette.primaryContainer : Color.clear, in: RoundedRectangle(cornerRadius: Radius.field))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(reason == option ? .isSelected : [])
                .accessibilityValue(Text(verbatim: "\(index + 1)/\(CancelReason.allCases.count)"))
                .accessibilityIdentifier(Self.identifiers[option] ?? "")
                if index < CancelReason.allCases.count - 1 { Divider() }
            }
        }
    }
}
