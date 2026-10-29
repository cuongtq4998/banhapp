import SwiftUI

/// A labelled field of the order form (`TextField`): the label above, the input in a rounded glass
/// field, and the error under it. The error is announced when it appears and read with the field.
struct FormField<Input: View>: View {
    let label: LocalizedStringResource
    let error: String?
    let errorIdentifier: String
    @ViewBuilder let input: Input

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .textStyle(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
            input
                .textStyle(Typography.body)
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, Spacing.inner)
                .padding(.vertical, Spacing.md)
                .frame(minHeight: Size.touchTarget)
                .background(Palette.surfaceSolid.opacity(0.8), in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                        .strokeBorder(error == nil ? Palette.tileStroke : Palette.error, lineWidth: error == nil ? Size.hairline : 2)
                }
            if let error {
                Text(verbatim: error)
                    .textStyle(Typography.caption)
                    .foregroundStyle(Palette.error)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(errorIdentifier)
                    .onAppear { UIAccessibility.post(notification: .announcement, argument: error) }
            }
        }
    }
}
