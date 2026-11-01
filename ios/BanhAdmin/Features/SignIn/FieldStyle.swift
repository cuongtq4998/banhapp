import BanhDesign
import SwiftUI

extension View {
    /// A text field on a solid rounded surface with a visible label above it.
    func labeledField(_ label: LocalizedStringResource) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label).textStyle(Typography.cardTitle).foregroundStyle(Palette.textPrimary)
            self
                .textStyle(Typography.body)
                .padding(.horizontal, Spacing.lg)
                .frame(minHeight: Size.primaryButtonHeight)
                .background(Palette.surfaceSolid, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        }
    }
}

/// Error text under a field; announced as an alert.
struct FieldError: View {
    let text: String
    let identifier: String

    var body: some View {
        Text(verbatim: text)
            .textStyle(Typography.caption)
            .foregroundStyle(Palette.error)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier(identifier)
    }
}
