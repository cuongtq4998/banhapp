import SwiftUI

/// The fixed list of delivery slots, one choice (`SlotChip`). The list is the same for every date and
/// a choice never changes which dates are available (AC-10).
struct SlotList: View {
    let model: DateViewModel

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(model.slots) { slot in
                let selected = model.selectedSlot == slot.id
                Button { model.select(slot) } label: {
                    Text(verbatim: slot.label)
                        .textStyle(Typography.button)
                        .foregroundStyle(selected ? Palette.onPrimary : Palette.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: Size.touchTarget)
                        .background(selected ? Palette.primary : Palette.glassFill, in: Capsule())
                        .overlay { Capsule().strokeBorder(Palette.tileStroke, lineWidth: Size.hairline) }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier(AccessibilityID.slotChip(slot.id.identifierText))
            }
        }
    }
}
