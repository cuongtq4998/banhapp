import SwiftUI

/// A large tappable tile of the home screen: title, a one-line hint and a chevron. The main tile is
/// the green gradient, the other one is glass (design board, home).
struct ActionTile: View {
    enum Emphasis { case primary, secondary }

    let title: LocalizedStringResource
    let hint: String
    var emphasis: Emphasis = .secondary
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title).textStyle(Typography.tileTitle)
                    Text(verbatim: hint).textStyle(Typography.caption).opacity(emphasis == .primary ? 0.9 : 1)
                        .foregroundStyle(emphasis == .primary ? Palette.onPrimary : Palette.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: Size.chevronTile, weight: .semibold))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.tileInset)
            .frame(maxWidth: .infinity, minHeight: Size.tileMinHeight)
            .foregroundStyle(emphasis == .primary ? Palette.onPrimary : Palette.textPrimary)
            .modifier(TileSurface(emphasis: emphasis))
            .contentShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : Motion.disabledOpacity)
        .accessibilityElement(children: .combine)
    }

}

/// Glass wraps the content (a glass background would be drawn over the text inside a glass container).
private struct TileSurface: ViewModifier {
    let emphasis: ActionTile.Emphasis

    @ViewBuilder
    func body(content: Content) -> some View {
        switch emphasis {
        case .primary:
            content.background {
                GradientBackground(shape: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
            }
        case .secondary:
            content.glassSurface(cornerRadius: Radius.tile)
        }
    }
}
