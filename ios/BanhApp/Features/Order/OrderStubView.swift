import SwiftUI

/// S-5 placeholder: the order flow opens here, empty, until the ordering slice fills it
/// (architecture.md section 11). Back leaves the flow and discards nothing: no flow data exists yet.
struct OrderStubView: View {
    private static let firstStep = 1

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(verbatim: Strings.stepLabel(step: Self.firstStep))
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
                .accessibilityIdentifier(AccessibilityID.orderStep)
            Text(Strings.step1)
                .font(Typography.titleMedium)
                .foregroundStyle(Palette.textPrimary)
        }
        .padding(.horizontal, Spacing.screenMargin)
        .padding(.top, Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .appBackground()
        .navigationTitle(Text(Strings.flowTitle))
        .navigationBarTitleDisplayMode(.inline)
    }
}
