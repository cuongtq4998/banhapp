import SwiftUI

/// "Bước n/4" with one segment per step, in a glass capsule beside the back button (`StepIndicator`).
struct StepIndicator: View {
    private static let segmentWidth: CGFloat = 22
    private static let segmentHeight: CGFloat = 5

    let current: Int
    let count: Int

    var body: some View {
        HStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                ForEach(1...count, id: \.self) { step in
                    Capsule()
                        .fill(step <= current ? Palette.primary : Palette.textPrimary.opacity(0.15))
                        .frame(width: Self.segmentWidth, height: Self.segmentHeight)
                }
            }
            .accessibilityHidden(true)
            Text(verbatim: Strings.stepLabel(step: current))
                .textStyle(Typography.caption)
                .foregroundStyle(Palette.textPrimary)
                .accessibilityIdentifier(AccessibilityID.orderStep)
        }
        .padding(.horizontal, Spacing.inner)
        .frame(minHeight: Size.backButton)
        .capsuleGlassSurface()
    }
}
