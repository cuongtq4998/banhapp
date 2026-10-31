import SwiftUI

extension View {
    /// Floats the screen's primary action above the safe area. The bar is a safe-area inset, so
    /// scrolling content gets bottom padding equal to the bar height and is never hidden.
    func bottomActionBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) { BottomActionBar(content: bar()) }
    }
}

private struct BottomActionBar<Content: View>: View {
    let content: Content

    var body: some View {
        VStack(spacing: Spacing.sm) { content }
            .padding(Spacing.inner)
            .glassSurface(cornerRadius: Radius.bar)
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.bottom, Size.barFloatOffset)
    }
}
