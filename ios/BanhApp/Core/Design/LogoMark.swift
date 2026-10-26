import SwiftUI

/// The shop logo: a rounded square (`radius.logo`). A generic cake symbol stands in until the shop
/// supplies its artwork (UI document section 11).
struct LogoMark: View {
    enum Scale {
        case large, small

        var side: CGFloat { self == .large ? Size.logoLarge : Size.logoSmall }
    }

    private static let symbolName = "birthday.cake.fill"
    private static let symbolRatio: CGFloat = 0.5

    let scale: Scale

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.logo * scale.side / Size.logoLarge, style: .continuous)
            .fill(Palette.primary)
            .frame(width: scale.side, height: scale.side)
            .overlay {
                Image(systemName: Self.symbolName)
                    .font(.system(size: scale.side * Self.symbolRatio))
                    .foregroundStyle(Palette.onPrimary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(Strings.logoLabel))
    }
}
