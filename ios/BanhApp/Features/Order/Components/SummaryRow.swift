import SwiftUI

/// A label and its value on the review (`SummaryRow`). The total is emphasised.
struct SummaryRow: View {
    let label: String
    let value: String
    var emphasized = false
    let identifier: String

    init(label: String, value: String, emphasized: Bool = false, identifier: String) {
        self.label = label
        self.value = value
        self.emphasized = emphasized
        self.identifier = identifier
    }

    init(label: LocalizedStringResource, value: String, emphasized: Bool = false, identifier: String) {
        self.init(label: String(localized: label), value: value, emphasized: emphasized, identifier: identifier)
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
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}
