import SwiftUI

/// Lays children side by side, and stacks them vertically at accessibility text sizes so rows wrap
/// instead of clipping (design system principle 5).
struct AdaptiveStack<Content: View>: View {
    var spacing: CGFloat = Spacing.md
    var verticalAlignment: VerticalAlignment = .center
    @ViewBuilder var content: Content
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
            : AnyLayout(HStackLayout(alignment: verticalAlignment, spacing: spacing))
        layout { content }
    }
}
