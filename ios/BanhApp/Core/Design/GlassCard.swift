import SwiftUI

/// Container for grouped content (`GlassCard`).
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = Radius.card
    var padding: CGFloat = Spacing.lg
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(cornerRadius: cornerRadius)
    }
}
