import SwiftUI

/// A label and its value on the review (`SummaryRow`). The total is emphasised.
struct SummaryRow: View {
    let label: String
    let value: String
    var emphasized = false
    /// The amount changed after `PRICE_CHANGED`: a warning fill behind the value.
    var highlighted = false
    let identifier: String

    init(label: String, value: String, emphasized: Bool = false, highlighted: Bool = false, identifier: String) {
        self.label = label
        self.value = value
        self.emphasized = emphasized
        self.highlighted = highlighted
        self.identifier = identifier
    }

    init(label: LocalizedStringResource, value: String, emphasized: Bool = false, highlighted: Bool = false, identifier: String) {
        self.init(label: String(localized: label), value: value, emphasized: emphasized,
                  highlighted: highlighted, identifier: identifier)
    }

    var body: some View {
        AdaptiveStack(spacing: Spacing.sm, verticalAlignment: .firstTextBaseline) {
            Text(verbatim: label)
                .textStyle(Typography.body)
                .foregroundStyle(emphasized ? Palette.textPrimary : Palette.textSecondary)
            Spacer(minLength: Spacing.sm)
            Text(verbatim: value)
                .textStyle(emphasized ? Typography.detailPrice : Typography.cardTitle)
                .foregroundStyle(emphasized ? Palette.primaryDeep : Palette.textPrimary)
                .multilineTextAlignment(.trailing)
                .background(highlighted ? Palette.warningContainer : .clear, in: RoundedRectangle(cornerRadius: Radius.field / 2))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}
