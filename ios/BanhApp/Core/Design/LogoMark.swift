import SwiftUI

/// The shop logo: a glass tile with the bánh tét glyph of the design board (drawn, so it stays sharp
/// at any size). The shop can replace the artwork later (UI document section 11).
struct LogoMark: View {
    enum Scale {
        case large, small

        var side: CGFloat { self == .large ? Size.logoLarge : Size.logoSmall }
        var cornerRadius: CGFloat { self == .large ? Radius.logoLarge : Radius.logoSmall }
    }

    let scale: Scale

    var body: some View {
        LogoGlyph()
            .stroke(
                Palette.primary,
                style: StrokeStyle(
                    lineWidth: scale.side * Size.logoGlyphRatio * Size.logoStrokeUnits / LogoGlyph.viewBox,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .frame(width: scale.side * Size.logoGlyphRatio, height: scale.side * Size.logoGlyphRatio)
            .frame(width: scale.side, height: scale.side)
            .glassSurface(cornerRadius: scale.cornerRadius)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(Strings.logoLabel))
    }
}

/// The board's logo (a tilted loaf with three ties), drawn in its 64 x 64 view box.
struct LogoGlyph: Shape {
    static let viewBox: CGFloat = 64
    private static let loaf = CGRect(x: 8, y: 22, width: 48, height: 20)
    private static let loafCorner: CGFloat = 10
    private static let tilt = Angle.degrees(-20)
    private static let center = CGPoint(x: 32, y: 32)
    private static let ties: [(from: CGPoint, dx: CGFloat, dy: CGFloat)] = [
        (CGPoint(x: 24, y: 20), -6, 22),
        (CGPoint(x: 36, y: 16), -6, 22),
        (CGPoint(x: 48, y: 12), -6, 22),
    ]

    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: Self.loaf, cornerRadius: Self.loafCorner, style: .continuous)
        path = path.applying(
            CGAffineTransform(translationX: Self.center.x, y: Self.center.y)
                .rotated(by: CGFloat(Self.tilt.radians))
                .translatedBy(x: -Self.center.x, y: -Self.center.y)
        )
        for tie in Self.ties {
            path.move(to: tie.from)
            path.addLine(to: CGPoint(x: tie.from.x + tie.dx, y: tie.from.y + tie.dy))
        }
        let scale = min(rect.width, rect.height) / Self.viewBox
        return path.applying(CGAffineTransform(scaleX: scale, y: scale)).offsetBy(dx: rect.minX, dy: rect.minY)
    }
}
