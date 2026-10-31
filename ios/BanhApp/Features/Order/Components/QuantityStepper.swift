import SwiftUI

/// Minus, value and plus in a glass capsule (`QuantityStepper`). Both buttons are 44 pt; a button at
/// its limit is disabled with no message (UI document 5.5).
struct QuantityStepper: View {
    let productID: String
    let name: String
    let value: Int
    let canDecrease: Bool
    let canIncrease: Bool
    let decrease: () -> Void
    let increase: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            stepButton(symbol: "minus", enabled: canDecrease, label: OrderStrings.qtyDecrease,
                       identifier: AccessibilityID.qtyDecrease(productID), action: decrease)
            Text(verbatim: String(value))
                .textStyle(Typography.cardTitle)
                .foregroundStyle(Palette.textPrimary)
                .frame(minWidth: Size.touchTarget)
                .accessibilityLabel(Text(verbatim: OrderStrings.format(OrderStrings.qtyValue, name, value)))
                .accessibilityIdentifier(AccessibilityID.qtyValue(productID))
            stepButton(symbol: "plus", enabled: canIncrease, label: OrderStrings.qtyIncrease,
                       identifier: AccessibilityID.qtyIncrease(productID), action: increase)
        }
        .capsuleGlassSurface()
    }

    private func stepButton(
        symbol: String, enabled: Bool, label: LocalizedStringResource, identifier: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: Size.chevronRow, weight: .semibold))
                .foregroundStyle(enabled ? Palette.textPrimary : Palette.textDisabled)
                .frame(width: Size.touchTarget, height: Size.touchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(Text(verbatim: OrderStrings.format(label, name)))
        .accessibilityIdentifier(identifier)
    }
}
