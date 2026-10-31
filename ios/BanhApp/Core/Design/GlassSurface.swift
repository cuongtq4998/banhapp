import SwiftUI

extension View {
    /// Gives the view a glass surface in a rounded shape, or the `material.fallback` rendering.
    func glassSurface(cornerRadius: CGFloat = Radius.card) -> some View {
        modifier(GlassSurface(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
    }

    func capsuleGlassSurface() -> some View {
        modifier(GlassSurface(shape: Capsule(style: .continuous)))
    }

    func circleGlassSurface() -> some View {
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
                    .overlay { shape.strokeBorder(edgeColor, lineWidth: Size.hairline) }
            }
        }
        .shadow(color: Palette.glassShadow, radius: GlassSpec.shadowRadius, y: GlassSpec.shadowOffsetY)
    }

    /// The board's glass is a white wash over a blurred background. Reduce Transparency and Increase
    /// Contrast get an opaque fill instead, so text never depends on what is behind it.
    @ViewBuilder
    private var fallbackFill: some View {
        if reduceTransparency || contrast == .increased {
            shape.fill(Palette.surfaceSolid)
        } else {
            shape.fill(Palette.glassFill).background(.ultraThinMaterial, in: shape)
        }
    }

    // Increase Contrast needs an edge that is visible on cream, not the white hairline.
    private var edgeColor: Color {
        contrast == .increased ? Palette.textSecondary : Palette.glassStroke
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
