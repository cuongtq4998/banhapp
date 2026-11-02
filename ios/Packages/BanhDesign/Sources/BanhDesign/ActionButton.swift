import SwiftUI

/// `PrimaryButton`, `SecondaryButton` and the destructive secondary in one component. The main action
/// is the green gradient capsule; the others are glass capsules.
public struct ActionButton: View {
    public enum Emphasis { case primary, secondary, destructive }

    let titleText: Text
    var systemImage: String?
    var emphasis: Emphasis
    var showsProgress: Bool
    let action: () -> Void

    public init(
        title: LocalizedStringResource, systemImage: String? = nil, emphasis: Emphasis = .primary,
        showsProgress: Bool = false, action: @escaping () -> Void
    ) {
        self.init(titleText: Text(title), systemImage: systemImage, emphasis: emphasis, showsProgress: showsProgress, action: action)
    }

    /// A title that is already final text (for example "Gọi +84...").
    public init(
        verbatim title: String, systemImage: String? = nil, emphasis: Emphasis = .primary,
        showsProgress: Bool = false, action: @escaping () -> Void
    ) {
        self.init(titleText: Text(verbatim: title), systemImage: systemImage, emphasis: emphasis, showsProgress: showsProgress, action: action)
    }

    private init(titleText: Text, systemImage: String?, emphasis: Emphasis, showsProgress: Bool, action: @escaping () -> Void) {
        self.titleText = titleText
        self.systemImage = systemImage
        self.emphasis = emphasis
        self.showsProgress = showsProgress
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if showsProgress { ProgressView().accessibilityHidden(true) }
                if let systemImage { Image(systemName: systemImage).accessibilityHidden(true) }
                titleText.textStyle(emphasis == .primary ? Typography.button : Typography.smallButton)
            }
            .frame(maxWidth: .infinity, minHeight: emphasis == .primary ? Size.primaryButtonHeight : Size.secondaryButtonHeight)
        }
        .buttonStyle(CapsuleButtonStyle(emphasis: emphasis))
    }
}

private struct CapsuleButtonStyle: ButtonStyle {
    let emphasis: ActionButton.Emphasis
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        surface(configuration.label.foregroundStyle(foreground))
            .scaleEffect(configuration.isPressed ? Motion.pressedScale : 1)
            .animation(Motion.standardSpring, value: configuration.isPressed)
            .contentShape(Capsule())
    }

    private var foreground: Color {
        guard isEnabled else { return Palette.textDisabled }
        switch emphasis {
        case .primary: return Palette.onPrimary
        case .secondary: return Palette.textPrimary
        case .destructive: return Palette.error
        }
    }

    @ViewBuilder
    private func surface(_ label: some View) -> some View {
        if emphasis == .primary {
            if isEnabled { label.background { GradientCapsule() } } else { label.background { Capsule().fill(Palette.disabledFill) } }
        } else {
            label.capsuleGlassSurface()
        }
    }
}

/// The green gradient of primary actions.
struct GradientCapsule: View {
    var body: some View {
        let shape = Capsule(style: .continuous)
        shape
            .fill(LinearGradient(colors: [Palette.primaryLight, Palette.primary], startPoint: .top, endPoint: .bottom))
            .overlay {
                shape.strokeBorder(
                    LinearGradient(colors: [Palette.buttonHighlight, .clear], startPoint: .top, endPoint: .center),
                    lineWidth: Size.hairline
                )
            }
            .shadow(color: Palette.buttonShadow, radius: 8, y: 6)
    }
}

/// Text-only button (resend, change e-mail, retry).
public struct TextLinkButton: View {
    let title: LocalizedStringResource
    let action: () -> Void

    public init(_ title: LocalizedStringResource, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title).textStyle(Typography.smallButton).frame(minHeight: Size.touchTarget)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.primary)
    }
}
