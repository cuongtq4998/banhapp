import SwiftUI

extension View {
    /// Gives the view a glass surface in a rounded shape, or the material fallback rendering.
    public func glassSurface(cornerRadius: CGFloat = Radius.card) -> some View {
        modifier(GlassSurface(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
    }

    public func capsuleGlassSurface() -> some View {
        modifier(GlassSurface(shape: Capsule(style: .continuous)))
    }

    public func circleGlassSurface() -> some View {
        modifier(GlassSurface(shape: Circle()))
    }
}

private struct GlassSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    @Environment(\.surfaceStyle) private var style
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        Group {
            if style == .liquidGlass, #available(iOS 26, *) {
                content.glassEffect(.regular, in: shape)
            } else {
                content
                    .background { fallbackFill }
                    .overlay { shape.strokeBorder(contrast == .increased ? Palette.textSecondary : Palette.glassStroke, lineWidth: Size.hairline) }
            }
        }
        .shadow(color: Palette.glassShadow, radius: 16, y: 8)
    }

    @ViewBuilder
    private var fallbackFill: some View {
        if reduceTransparency || contrast == .increased {
            shape.fill(Palette.surfaceSolid)
        } else {
            shape.fill(Palette.glassFill).background(.ultraThinMaterial, in: shape)
        }
    }
}

/// Container for grouped content.
public struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat
    var padding: CGFloat
    let content: Content

    public init(cornerRadius: CGFloat = Radius.card, padding: CGFloat = Spacing.lg, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(cornerRadius: cornerRadius)
    }
}
