import SwiftUI

extension View {
    /// Gives the view a glass surface in a rounded shape, or the `material.fallback` rendering.
    func glassSurface(cornerRadius: CGFloat = Radius.card) -> some View {
        modifier(GlassSurface(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
    }

    func capsuleGlassSurface() -> some View {
        modifier(GlassSurface(shape: Capsule(style: .continuous)))
    }
}

private struct GlassSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    @Environment(\.surfaceStyle) private var style
    @Environment(\.colorSchemeContrast) private var contrast

    @ViewBuilder
    func body(content: Content) -> some View {
        if style == .liquidGlass, #available(iOS 26, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background { shape.fill(Palette.surfaceSolid) }
                .background(.ultraThinMaterial, in: shape)
                .overlay { shape.strokeBorder(edgeColor, lineWidth: Size.hairline) }
        }
    }

    // Increase Contrast needs an edge that is visible on cream, not the white hairline.
    private var edgeColor: Color {
        contrast == .increased ? Palette.textSecondary : Palette.surfaceStroke
    }
}

/// Groups glass shapes so iOS 26 renders them together (and lets them morph); a plain container before.
struct GlassGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: Spacing.lg) { content }
        } else {
            content
        }
    }
}
