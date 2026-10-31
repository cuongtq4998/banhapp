import SwiftUI

/// The full privacy notice at the top of S-7 (FR-20, AC-30): always visible, fixed local text, wraps
/// at any text size. One accessibility container; the title is a heading and the link the only control.
struct PrivacyNoticeCard: View {
    let open: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    Image(systemName: "lock.shield").foregroundStyle(Palette.primaryDeep).accessibilityHidden(true)
                    Text(OrderStrings.privacyTitle)
                        .textStyle(Typography.cardTitle)
                        .foregroundStyle(Palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier(AccessibilityID.privacyTitle)
                }
                Text(OrderStrings.privacyBody)
                    .textStyle(Typography.body)
                    .foregroundStyle(Palette.textSecondary)
                    .accessibilityIdentifier(AccessibilityID.privacyBody)
                Text(OrderStrings.privacyDraft)
                    .textStyle(Typography.body)
                    .foregroundStyle(Palette.textSecondary)
                    .accessibilityIdentifier(AccessibilityID.privacyDraft)
                PrivacyTextLink(title: OrderStrings.privacyLink, identifier: AccessibilityID.privacyLink, action: open)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.privacyCard)
    }
}

/// Underlined text link, full width and at least 44 pt high; the same control serves S-7 and S-8.
struct PrivacyTextLink: View {
    let title: LocalizedStringResource
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .textStyle(Typography.body)
                .underline()
                .foregroundStyle(Palette.primaryDeep)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: Size.touchTarget, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isLink)
        .accessibilityHint(Text(OrderStrings.privacyLinkHint))
        .accessibilityIdentifier(identifier)
    }
}
