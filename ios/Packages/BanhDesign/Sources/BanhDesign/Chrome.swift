import SwiftUI

/// The round glass back button; the navigation bar is hidden on screens that use it.
public struct BackButton: View {
    let label: LocalizedStringResource
    let identifier: String
    let action: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    /// `action` nil: dismisses the current screen.
    public init(label: LocalizedStringResource, identifier: String, action: (() -> Void)? = nil) {
        self.label = label
        self.identifier = identifier
        self.action = action
    }

    public var body: some View {
        Button { if let action { action() } else { dismiss() } } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
                .frame(width: Size.touchTarget, height: Size.touchTarget)
                .circleGlassSurface()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(identifier)
    }
}

extension View {
    /// Hides the system navigation bar but keeps the swipe-back gesture.
    public func customBackNavigation() -> some View {
        toolbar(.hidden, for: .navigationBar).background(SwipeBackEnabler())
    }

    /// Floats the screen's actions above the safe area; scrolling content gets the bar's height as padding.
    public func bottomActionBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            bar()
                .padding(Spacing.inner)
                .glassSurface(cornerRadius: Radius.bar)
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.bottom, Size.barFloatOffset)
        }
    }
}

private struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            navigationController?.interactivePopGestureRecognizer?.delegate = nil
        }
    }
}

/// Lays children side by side, and stacks them vertically at accessibility text sizes.
public struct AdaptiveStack<Content: View>: View {
    var spacing: CGFloat
    let content: Content
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(spacing: CGFloat = Spacing.md, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
            : AnyLayout(HStackLayout(alignment: .center, spacing: spacing))
        layout { content }
    }
}
