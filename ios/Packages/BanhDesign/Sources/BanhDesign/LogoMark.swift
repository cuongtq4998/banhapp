import SwiftUI

/// The shop logo: a glass tile with the loaf glyph of the design board, drawn so it stays sharp.
public struct LogoMark: View {
    let label: LocalizedStringResource

    public init(label: LocalizedStringResource) { self.label = label }

    public var body: some View {
        LogoGlyph()
            .stroke(
                Palette.primary,
                style: StrokeStyle(
                    lineWidth: Size.logo * Size.logoGlyphRatio * Size.logoStrokeUnits / LogoGlyph.viewBox,
                    lineCap: .round, lineJoin: .round
                )
            )
            .frame(width: Size.logo * Size.logoGlyphRatio, height: Size.logo * Size.logoGlyphRatio)
            .frame(width: Size.logo, height: Size.logo)
            .glassSurface(cornerRadius: Radius.logo)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(label))
    }
}

struct LogoGlyph: Shape {
    static let viewBox: CGFloat = 64
    private static let ties: [(from: CGPoint, dx: CGFloat, dy: CGFloat)] = [
        (CGPoint(x: 24, y: 20), -6, 22), (CGPoint(x: 36, y: 16), -6, 22), (CGPoint(x: 48, y: 12), -6, 22),
    ]

    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: CGRect(x: 8, y: 22, width: 48, height: 20), cornerRadius: 10, style: .continuous)
        path = path.applying(
            CGAffineTransform(translationX: 32, y: 32).rotated(by: CGFloat(Angle.degrees(-20).radians)).translatedBy(x: -32, y: -32)
        )
        for tie in Self.ties {
            path.move(to: tie.from)
            path.addLine(to: CGPoint(x: tie.from.x + tie.dx, y: tie.from.y + tie.dy))
        }
        let scale = min(rect.width, rect.height) / Self.viewBox
        return path.applying(CGAffineTransform(scaleX: scale, y: scale)).offsetBy(dx: rect.minX, dy: rect.minY)
    }
}
