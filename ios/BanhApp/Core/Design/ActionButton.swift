import SwiftUI

/// `PrimaryButton` and `SecondaryButton` (also the Zalo and phone `ContactButton`s) in one component:
/// the two differ only in emphasis. Liquid Glass styles on iOS 26, filled and material capsules otherwise.
struct ActionButton: View {
    enum Emphasis { case primary, secondary }

    let title: LocalizedStringResource
    var systemImage: String?
    var emphasis: Emphasis = .primary
    let action: () -> Void

    @Environment(\.surfaceStyle) private var surfaceStyle
    @State private var pressCount = 0

    var body: some View {
        styled
            .buttonBorderShape(.capsule)
            .sensoryFeedback(.impact(weight: .light), trigger: pressCount)
    }

    @ViewBuilder
    private var styled: some View {
        if surfaceStyle == .liquidGlass, #available(iOS 26, *) {
            switch emphasis {
            case .primary: button.buttonStyle(.glassProminent).tint(Palette.primary)
            case .secondary: button.buttonStyle(.glass)
            }
        } else {
            button.buttonStyle(FallbackCapsuleButtonStyle(emphasis: emphasis))
        }
    }

    private var button: some View {
        Button {
            pressCount += 1
            action()
        } label: {
            label.frame(maxWidth: .infinity, minHeight: Size.buttonHeight)
        }
    }

    private var label: some View {
        HStack(spacing: Spacing.sm) {
            if let systemImage { Image(systemName: systemImage).accessibilityHidden(true) }
            Text(title).font(Typography.label)
        }
    }
}

/// Plain capsules for iOS 17 to 25 and for Reduce Transparency: filled for the main action, material
/// for the alternative (`material.fallback`).
private struct FallbackCapsuleButtonStyle: ButtonStyle {
    let emphasis: ActionButton.Emphasis
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .background { background }
            .scaleEffect(configuration.isPressed ? Motion.pressedScale : 1)
            .animation(Motion.standardSpring, value: configuration.isPressed)
            .contentShape(Capsule())
    }

    private var foreground: Color {
        guard isEnabled else { return Palette.textDisabled }
        return emphasis == .primary ? Palette.onPrimary : Palette.onPrimaryContainer
    }

    @ViewBuilder
    private var background: some View {
        if !isEnabled {
            Capsule().fill(Palette.disabledFill)
        } else if emphasis == .primary {
            Capsule().fill(Palette.primary)
        } else {
            Capsule()
                .fill(Palette.primaryContainer)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay { Capsule().strokeBorder(Palette.surfaceStroke, lineWidth: Size.hairline) }
        }
    }
}
