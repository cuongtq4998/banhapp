import SwiftUI

/// Container for grouped content (`GlassCard`).
struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface()
            .shadow(color: CardShadow.color, radius: CardShadow.radius, y: CardShadow.offsetY)
    }
}
