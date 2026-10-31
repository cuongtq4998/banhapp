import SwiftUI

/// `PrimaryButton` and `SecondaryButton` (also the Zalo and phone `ContactButton`s) in one component:
/// the two differ only in emphasis. The main action is the board's green gradient capsule on every iOS
/// version; the alternative is a glass capsule (Liquid Glass on iOS 26, material before).
struct ActionButton: View {
    enum Emphasis { case primary, secondary }

    let title: LocalizedStringResource
    var systemImage: String?
    var emphasis: Emphasis = .primary
    /// A spinner before the title while the action runs (`BTN_SENDING`).
    var showsProgress = false
    let action: () -> Void

    @State private var pressCount = 0

    var body: some View {
        Button {
            pressCount += 1
            action()
        } label: {
            label.frame(maxWidth: .infinity, minHeight: minHeight)
        }
        .buttonStyle(CapsuleButtonStyle(emphasis: emphasis))
        .sensoryFeedback(.impact(weight: .light), trigger: pressCount)
    }

    private var minHeight: CGFloat {
        emphasis == .primary ? Size.primaryButtonHeight : Size.secondaryButtonHeight
    }

    private var textStyle: TextStyle {
        emphasis == .primary ? Typography.button : Typography.contactButton
    }

    private var label: some View {
        HStack(spacing: Spacing.sm) {
            if showsProgress { ProgressView().accessibilityHidden(true) }
            if let systemImage { Image(systemName: systemImage).accessibilityHidden(true) }
            Text(title).textStyle(textStyle)
        }
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
        return emphasis == .primary ? Palette.onPrimary : Palette.textPrimary
    }

    /// Glass has to wrap the label (not sit behind it): inside a `GlassEffectContainer` a glass
    /// background is drawn over the label and blurs it.
    @ViewBuilder
    private func surface(_ label: some View) -> some View {
        switch (emphasis, isEnabled) {
        case (.primary, true): label.background { GradientCapsule() }
        case (.primary, false): label.background { Capsule().fill(Palette.disabledFill) }
        case (.secondary, _): label.capsuleGlassSurface()
        }
    }
}

/// The green gradient of primary actions: lighter at the top, a white highlight on the top edge and a
/// green shadow below, as on the board.
struct GradientCapsule: View {
    var body: some View { GradientBackground(shape: Capsule(style: .continuous)) }
}

/// The same fill in any shape (the home tile is a rounded rectangle).
struct GradientBackground<S: InsettableShape>: View {
    let shape: S

    var body: some View {
        shape
            .fill(LinearGradient(colors: [Palette.primaryLight, Palette.primary], startPoint: .top, endPoint: .bottom))
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [Palette.buttonHighlight, .clear],
                        startPoint: .top,
                        endPoint: .center
                    ),
                    lineWidth: Size.hairline
                )
            }
            .shadow(color: Palette.buttonShadow, radius: ButtonShadow.radius, y: ButtonShadow.offsetY)
    }
}
