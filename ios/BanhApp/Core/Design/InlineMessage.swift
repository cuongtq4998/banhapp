import SwiftUI

/// A message near a control or at the top of a section (`InlineMessage`): an icon and text on a tinted
/// container, with an optional action button. Announced when it appears (UI document 9).
struct InlineMessage: View {
    enum Kind { case error, info }

    let kind: Kind
    let text: String
    var actionTitle: LocalizedStringResource?
    var action: (() -> Void)?
    var actionIdentifier = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Image(systemName: symbol).foregroundStyle(tint).accessibilityHidden(true)
                Text(verbatim: text)
                    .textStyle(Typography.body)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let actionTitle, let action {
                ActionButton(title: actionTitle, emphasis: .secondary, action: action)
                    .accessibilityIdentifier(actionIdentifier)
            }
        }
        .padding(Spacing.inner)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(container, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .accessibilityElement(children: .contain)
        .onAppear { UIAccessibility.post(notification: .announcement, argument: text) }
    }

    private var symbol: String {
        kind == .error ? "exclamationmark.circle.fill" : "info.circle.fill"
    }

    private var tint: Color { kind == .error ? Palette.error : Palette.primary }
    private var container: Color { kind == .error ? Palette.errorContainer : Palette.primaryContainer }
}
